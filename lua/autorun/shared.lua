AddCSLuaFile()

--VJ L4D2 SI M16 code
function Flinch(wpn, v)
    v.NextL4DFlinchT = v.NextL4DFlinchT or 0
    if CurTime() < v.NextL4DFlinchT then return end
    local isCI = v.Zombie_CanPuke != nil
    v.Flinching = true
    v:StopAttacks(true)
    v.PlayingAttackAnimation = false
    local posF = (v:GetPos() +v:OBBCenter()) +v:GetForward() *115
    local posB = (v:GetPos() +v:OBBCenter()) +v:GetForward() *-115
    local posL = (v:GetPos() +v:OBBCenter()) +v:GetRight() *-115
    local posR = (v:GetPos() +v:OBBCenter()) +v:GetRight() *115
    local tbl = {posF,posB,posL,posR}
    local nearestDist = 9999999
    local cPos = nil
    for _,v in pairs(tbl) do
        if v:Distance(wpn:GetPos()) < nearestDist then
            nearestDist = v:Distance(wpn:GetPos())
            cPos = v
        end
    end
    if cPos == nil then return end
    if isCI && !v.Shove_Forward then
        v.Shove_Forward = "Shoved_Backward_01"
        v.Shove_Backward = "Shoved_Forward_01"
        v.Shove_Left = "Shoved_Rightward_01"
        v.Shove_Right = "Shoved_Leftward_01"
    end
    local anim = (cPos == posF && v.Shove_Forward) or (cPos == posB && v.Shove_Backward) or (cPos == posL && v.Shove_Left) or (cPos == posR && v.Shove_Right) or v.Shove_Forward or false
    if isCI then
        if anim == v.Shove_Forward then
            local tr = util.TraceHull({
                start = (v:GetPos() +v:OBBCenter()),
                endpos = posB,
                mask = MASK_SHOT,
                filter = {v},
                mins = v:OBBMins(),
                maxs = v:OBBMaxs()
            })
            if tr.Hit && tr.HitPos:Distance(v:GetPos() +v:OBBCenter()) <= 25 then
                anim = "Shoved_Backward_IntoWall_01"
            end
        elseif anim == v.Shove_Backward then
            local tr = util.TraceHull({
                start = (v:GetPos() +v:OBBCenter()),
                endpos = posF,
                mask = MASK_SHOT,
                filter = {v},
                mins = v:OBBMins(),
                maxs = v:OBBMaxs()
            })
            if tr.Hit && tr.HitPos:Distance(v:GetPos() +v:OBBCenter()) <= 25 then
                anim = "Shoved_Forward_IntoWall_02"
            end
        elseif anim == v.Shove_Left then
            local tr = util.TraceHull({
                start = (v:GetPos() +v:OBBCenter()),
                endpos = posR,
                mask = MASK_SHOT,
                filter = {v},
                mins = v:OBBMins(),
                maxs = v:OBBMaxs()
            })
            if tr.Hit && tr.HitPos:Distance(v:GetPos() +v:OBBCenter()) <= 25 then
                anim = "Shoved_Rightward_IntoWall_01"
            end
        elseif anim == v.Shove_Right then
            local tr = util.TraceHull({
                start = (v:GetPos() +v:OBBCenter()),
                endpos = posL,
                mask = MASK_SHOT,
                filter = {v},
                mins = v:OBBMins(),
                maxs = v:OBBMaxs()
            })
            if tr.Hit && tr.HitPos:Distance(v:GetPos() +v:OBBCenter()) <= 25 then
                anim = "Shoved_Leftward_IntoWall_02"
            end
        end
    end
    if !anim then return end
    if v.OnShoved then
        anim = v:OnShoved(anim,wpn.Owner)
    end
    v:VJ_ACT_PLAYACTIVITY(anim,true,false,false)
    local animdur = (v:DecideAnimationLength(anim,false))
    timer.Create("timer_act_flinching" .. v:EntIndex(),animdur,1,function() v.Flinching = false end)
    v.NextFlinchT = CurTime() +animdur
    v.NextL4DFlinchT = CurTime() +(animdur *0.25)
end

-- Refactored code from weapon_vj_base_ex
function GetNearestPoint(wpn, argent, SameZ)
    if !IsValid(argent) then return end
    SameZ = SameZ or false -- Should the Z of the pos be the same as the NPC's?
    local myNearestPoint = wpn:GetOwner():EyePos()
    local NearestPositions = {MyPosition=Vector(0,0,0), EnemyPosition=Vector(0,0,0)}
    local Pos_Enemy, Pos_Self = argent:NearestPoint(myNearestPoint + argent:OBBCenter()), wpn:NearestPoint(argent:GetPos() + wpn:OBBCenter())
    Pos_Enemy.z, Pos_Self.z = argent:GetPos().z, myNearestPoint.z
    if SameZ == true then
        Pos_Enemy = Vector(Pos_Enemy.x,Pos_Enemy.y,wpn:SetNearestPointToEntityPosition().z)
        Pos_Self = Vector(Pos_Self.x,Pos_Self.y,wpn:SetNearestPointToEntityPosition().z)
    end
    NearestPositions.MyPosition = Pos_Self
    NearestPositions.EnemyPosition = Pos_Enemy
    return NearestPositions
end

hook.Add( "Initialize", "ReplaceMeleeBehaviourModuleForVJL4D2", function()

    -- Overwrite method (may conflict with MW base plus)
    local MW = weapons.GetStored( "mg_base" )
    local tick = engine.TickInterval()

    function MW:MeleeBehaviourModule()

        if (game.SinglePlayer() && CLIENT) then return end

        -- Refactored code to "shove" L4D2 NPCs 

        -- All this stuff needs to be run on the Client/shared
        if (((self:GetOwner():KeyDown(IN_USE) || self.Melee) && self:GetOwner():KeyPressed(IN_ATTACK)) || self:GetOwner():KeyPressed(IN_ALT1)) then 
            self:SetSafety(false)
            if (self:CanMelee()) then
                if (CurTime() > self:GetNextMeleeTime()) then

                    self:SetIsReloading(false)
                    self:PlayerGesture(GESTURE_SLOT_ATTACK_AND_RELOAD, self.HoldTypes[self.HoldType].Melee)
                    
                    local size = self.Animations["Melee"].Size
                    local range = self.Animations["Melee"].Range
                    local meleeRange = range * 2

                    --self:GetOwner():LagCompensation(true)
                    
                    -- local tr = util.TraceHull({
                    --     start = self:GetOwner():EyePos(),
                    --     endpos = self:GetOwner():EyePos() + self:GetOwner():EyeAngles():Forward() * range,
                    --     filter = {self:GetOwner(), self},
                    --     mins = Vector(-size, -size, -size),
                    --     maxs = Vector(size, size, size),
                    --     mask = MASK_SHOT_HULL,
                    -- })   
                    local bHitNPC = false
                    local bHit = false
                    local hitCount = 0 
                    local dmgInfo = DamageInfo() 
                    local sound = ""
                    -- This needs to be in server
                    if SERVER then
                        -- Modified from SWEP:MeleeCode() in VJ Base
                        for _,v in pairs(ents.FindInSphere(self:GetOwner():GetShootPos(), meleeRange)) do
                            if v:IsNPC() && v != self && v != owner then
                                dmgInfo = DamageInfo() 
                                dmgInfo:SetInflictor(self)
                                dmgInfo:SetAttacker(self:GetOwner())
                                dmgInfo:SetDamage(self.Animations["Melee_Hit"].Damage)
                                dmgInfo:SetDamagePosition(GetNearestPoint(self, v).MyPosition)
                                dmgInfo:SetDamageForce(self:GetOwner():EyeAngles():Forward() * (self.Animations["Melee_Hit"].Damage * (meleeRange)))
                                dmgInfo:SetDamageType(DMG_CLUB + DMG_ALWAYSGIB)
                                local inCone = (self:GetOwner():GetAimVector():Angle():Forward():Dot(((v:GetPos() +v:OBBCenter()) - self:GetOwner():GetShootPos()):GetNormalized()) > math.cos(math.rad((meleeRange))))
                                if inCone then
                                    if (v.VJ_L4D2_SpecialInfected or v.Shove_Forward or v.Zombie_CanPuke != nil) && !v.VJ_NoFlinch && v:Health() > 0 then
                                        dmgInfo:SetDamage(self.Animations["Melee_Hit"].Damage * 0.5)
                                        bHitNPC = true
                                        bHit = true
                                        Flinch(self,v)
                                    end 
                                    if hitCount < 3 then
                                        hitCount = hitCount + 1 
                                    end
                                end
                                -- for some reason sounds all play at the same time for each infected unless you use a timer, probably has to do with prediction 
                                -- I suck at coding, this is a quick and dirty way to make the sound play multiple times for multiple NPCs 
                                if hitCount > 1 then
                                    if self.Slot == 1 then
                                        sound = Sound("MW_Melee.Flesh_Small")
                                    else
                                        sound = Sound("MW_Melee.Flesh_Medium")
                                    end
                                    -- subtract one for the one that plays by default 
                                    timer.Simple( (hitCount - 1) * 0.02, function () self:DoSound(sound) end)
                                    -- self:DoSound(Sound("MW_Melee.Flesh_Medium"))
                                end
                                if v:IsNPC() then 
                                    v:TakeDamageInfo(dmgInfo,self:GetOwner())
                                end
                            end
                        end
                    end
                    -- self:FireBullets({
                    --     Src = self:GetOwner():EyePos(),
                    --     Dir = self:GetOwner():EyeAngles():Forward(),
                    --     Distance = range,
                    --     HullSize = size,
                    --     Tracer = 0,
                    --     Callback = function(attacker, btr, dmgInfo)
                    --         -- print(btr.Entity)
                    --         -- Flinch(btr.Entity)
                    --         dmgInfo:SetDamage(self.Animations["Melee_Hit"].Damage)
                    --         dmgInfo:SetInflictor(self)
                    --         dmgInfo:SetAttacker(self:GetOwner())
                    --         dmgInfo:SetDamagePosition(btr.HitPos)
                    --         dmgInfo:SetDamageForce(self:GetOwner():EyeAngles():Forward() * (self.Animations["Melee_Hit"].Damage * 100))
                    --         dmgInfo:SetDamageType(DMG_CLUB + DMG_ALWAYSGIB)

                    --         bHit = true
                    --     end
                    -- })
                    
                    -- Used purely for world collisions so it'll make the right sound and play the right animation
                    if bHitNPC == false then 
                        -- reused discarded trace code from original base
                        local tr = util.TraceHull({
                            start = self:GetOwner():EyePos(),
                            endpos = self:GetOwner():EyePos() + self:GetOwner():EyeAngles():Forward() * range,
                            filter = {self:GetOwner(), self},
                            mins = Vector(-size, -size, -size),
                            maxs = Vector(size, size, size),
                            mask = MASK_SHOT_HULL,
                        })   
                    
                        if tr.Hit then
                            bHit = true
                        end
                    end

                    if (bHit) then
                        self:SetNextMeleeTime(CurTime() + self:GetAnimLength("Melee_Hit", self.Animations["Melee_Hit"].Length))
                        if (IsFirstTimePredicted()) then self:PlayViewModelAnimation("Melee_Hit") end
                    else
                        self:SetNextMeleeTime(CurTime() + self:GetAnimLength("Melee", self.Animations["Melee"].Length))
                        if (IsFirstTimePredicted()) then self:PlayViewModelAnimation("Melee") end
                    end 

                    --debugoverlay.Box(tr.HitPos, Vector(-size, -size, -size), Vector(size, size, size), 10, Color(255, 0, 0, 50))

                    --self:GetOwner():LagCompensation(false)
                end
            end
        end
    end
end)