-- effects.lua for Longsword Master (compatible with slight local modifications)

if not SWEP then return end

local function LookupFirstAttachment(vm, names)
    if not IsValid(vm) then return nil end
    for _, n in ipairs(names) do
        if not n then continue end
        local id = vm:LookupAttachment(n)
        if id and id > 0 then return id end
    end
    return nil
end

function SWEP:DoMuzzleEffect(attID)
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local vm = ply:GetViewModel()
    if not IsValid(vm) then return end
    if not attID then return end

    local posang = vm:GetAttachment(attID)
    if not posang then return end

    local ef = EffectData()
    ef:SetOrigin(ply:GetShootPos())
    ef:SetStart(ply:GetShootPos())
    ef:SetNormal(ply:EyeAngles():Forward())
    ef:SetEntity(vm)
    ef:SetAttachment(attID)
    ef:SetScale(self.IronsightsMuzzleFlashScale or 1)
    util.Effect(self.IronsightsMuzzleFlash or "ls_muzzleflash", ef)
end

function SWEP:DoEjectCheck()
    if (self.Primary.BulletModel or self.Primary.BulletEffect) and self.Primary.EjectAttachment then
        if self.Primary.BulletEjectDelay then
            timer.Simple(self.Primary.BulletEjectDelay, function()
                if not IsValid(self) then return end
                if self.DoBulletEjection then self:DoBulletEjection() end
            end)
        else
            if self.DoBulletEjection then self:DoBulletEjection() end
        end
    end
end

function SWEP:ResolveFireAnim()
    if self.GetFireAnimation and type(self.GetFireAnimation) == "function" then
        local ok, anim = pcall(self.GetFireAnimation, self)
        if ok and anim then return anim end
    end
    if self.FireAnims and istable(self.FireAnims) and #self.FireAnims > 0 then
        return self.FireAnims[math.random(1, #self.FireAnims)]
    end
    return self.FireAnim or ACT_VM_PRIMARYATTACK
end

function SWEP:ShootEffects()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local vm = ply:GetViewModel()

    local anim = self:ResolveFireAnim()

    if not self:GetIronsights() or self:ShouldAnimateFire() then
        if self.PlayAnim then
            self:PlayAnim(anim)
        else
            if IsValid(vm) then
                vm:SendViewModelMatchingSequence(anim)
            end
        end
        if self.QueueIdle then self:QueueIdle() end
    end

    if self.PlayFireSound then
        self:PlayFireSound()
    else
        if self.Primary and self.Primary.Sound then
            self:EmitWeaponSound(self.Primary.Sound)
        end
    end

    local muzzleAttachments = { self.MuzzleAttachment, "muzzle", "A_Muzzle", "muzzle_silenced", "muzzle_flash" }
    local muz = nil
    if IsValid(vm) then
        muz = LookupFirstAttachment(vm, muzzleAttachments)
    end

    if CLIENT then
        self.BlurFraction = 1
        if self.ShouldResetCustomRecoil and type(self.ShouldResetCustomRecoil) == "function" then
            if self:ShouldResetCustomRecoil() and (game.SinglePlayer() or IsFirstTimePredicted()) then
                if self.ResetCustomRecoil then self:ResetCustomRecoil() end
            end
        end

        self.RecoilCameraRoll = 1
        self.RecoilCameraFreq = math.random(15, 23)
        self.RecoilCameraLastShoot = CurTime()

        local isThirdperson = ply:ShouldDrawLocalPlayer()
        if not isThirdperson and muz then
            self:DoMuzzleEffect(muz)
        end

        self:DoEjectCheck()
    end

    if IsValid(ply) then
        ply:MuzzleFlash()
        if self.PlayAnimWorld then
            self:PlayAnimWorld(ACT_VM_PRIMARYATTACK)
        end
        ply:SetAnimation(PLAYER_ATTACK1)
    end

    if self.QueueIdle then self:QueueIdle() end
    if self.CustomShootEffects then pcall(self.CustomShootEffects, self) end

    if self.PumpDelay then
        timer.Simple(self.PumpDelay, function()
            if not IsValid(self) then return end
            local animPump = self.PumpAnimation or ACT_VM_PULLBACK
            if self.GetPumpAnimation and type(self.GetPumpAnimation) == "function" then
                local ok, a = pcall(self.GetPumpAnimation, self)
                if ok and a then animPump = a end
            end
            if self.PlayAnim then
                self:PlayAnim(animPump)
            else
                if IsValid(vm) then vm:SendViewModelMatchingSequence(animPump) end
            end
            if self.QueueIdle then self:QueueIdle() end
        end)
    end
end

-- Optional helper: safe muzzle flash for external callers
function SWEP:DoMuzzleFlashSafe()
    local ply = self:GetOwner()
    if not IsValid(ply) then return end
    local vm = ply:GetViewModel()
    if not IsValid(vm) then return end
    local muzzleAttachments = { self.MuzzleAttachment, "muzzle", "A_Muzzle", "muzzle_silenced", "muzzle_flash" }
    local muz = LookupFirstAttachment(vm, muzzleAttachments)
    if muz then self:DoMuzzleEffect(muz) end
end
