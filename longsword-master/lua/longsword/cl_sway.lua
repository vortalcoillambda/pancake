if CLIENT == false then return end

local sv_prefix = "ls_sway_"

CreateClientConVar(sv_prefix.."enable", "1", true, false)
CreateClientConVar(sv_prefix.."intensity", "1.0", true, false)
CreateClientConVar(sv_prefix.."multiplier", "1.0", true, false)

-- ADS reductions (new!)
CreateClientConVar(sv_prefix.."ads_mult_ang",  "0.35", true, false)
CreateClientConVar(sv_prefix.."ads_mult_pos",  "0.30", true, false)
CreateClientConVar(sv_prefix.."ads_mult_roll", "0.10", true, false)

CreateClientConVar(sv_prefix.."breath_amp", "0.6", true, false)
CreateClientConVar(sv_prefix.."vel_influence", "1.0", true, false)
CreateClientConVar(sv_prefix.."smooth", "12", true, false)
CreateClientConVar(sv_prefix.."max_ang", "4", true, false)
CreateClientConVar(sv_prefix.."max_pos", "2", true, false)
CreateClientConVar(sv_prefix.."debug", "0", true, false)

local function CV(n) return GetConVar(sv_prefix..n) end

local function EnsureSwayState(wep)
    if not IsValid(wep) then return end
    if not wep._ls_sway then
        wep._ls_sway = {
            targetPitch = 0,
            targetYaw = 0,
            targetRoll = 0,
            targetPos = Vector(0,0,0),

            angSpringVel = Vector(0,0,0),
            posSpringVel = Vector(0,0,0),

            smoothedMouseX = 0,
            smoothedMouseY = 0,
            lastFrame = RealTime(),
            playerSpeed = 0
        }
    end
    return wep._ls_sway
end

hook.Add("StartCommand", "LS_Sway_StartCommand", function(ply, cmd)
    if not ply or not ply:IsValid() then return end
    if not CV("enable"):GetBool() then return end

    local wep = ply:GetActiveWeapon()
    if not IsValid(wep) or not wep.IsLongsword then return end

    local st = EnsureSwayState(wep)
    if not st then return end

    local mx, my = cmd:GetMouseX(), cmd:GetMouseY()
    st.smoothedMouseX = Lerp(0.6, st.smoothedMouseX, mx)
    st.smoothedMouseY = Lerp(0.6, st.smoothedMouseY, my)

    st.targetMouseX = st.smoothedMouseX
    st.targetMouseY = st.smoothedMouseY
    st.playerSpeed = ply:GetVelocity():Length2D()

    st.lastFrame = RealTime()
end)

local function SpringApproach(current, velocity, target, k, d, dt)
    if dt <= 0 then return current, velocity end
    local f = k * (target - current)
    local accel = f - d * velocity
    velocity = velocity + accel * dt
    current = current + velocity * dt
    return current, velocity
end

hook.Add("CalcViewModelView", "LS_Sway_CalcViewModelView", function(wep, vm, oldPos, oldAng)
    if not IsValid(wep) or not IsValid(vm) then return end
    local ply = LocalPlayer()
    if not ply or not ply:IsValid() then return end

    if not CV("enable"):GetBool() then return end
    if not wep.IsLongsword then return end

    local st = EnsureSwayState(wep)
    if not st then return end

    local dt = math.Clamp(RealTime() - st.lastFrame, 0, 0.1)

    local intensity  = CV("intensity"):GetFloat()
    local globalMul  = CV("multiplier"):GetFloat()

    local adsAngMul  = CV("ads_mult_ang"):GetFloat()
    local adsPosMul  = CV("ads_mult_pos"):GetFloat()
    local adsRollMul = CV("ads_mult_roll"):GetFloat()

    local breathAmp  = CV("breath_amp"):GetFloat()
    local velInfluence = CV("vel_influence"):GetFloat()
    local smoothness = CV("smooth"):GetFloat()

    local maxAng = CV("max_ang"):GetFloat()
    local maxPos = CV("max_pos"):GetFloat()

    local ads = wep.GetIronsights and wep:GetIronsights() or false
    local adsAngScale  = ads and adsAngMul  or 1
    local adsPosScale  = ads and adsPosMul  or 1
    local adsRollScale = ads and adsRollMul or 1

    local mx = st.targetMouseX or 0
    local my = st.targetMouseY or 0

    -- Core mouse sway
    local tgtPitch = (-my / 50) * intensity * globalMul * adsAngScale
    local tgtYaw   = (mx  / 50) * intensity * globalMul * adsAngScale

    local velFrac = math.Clamp(st.playerSpeed / 250, 0, 1) * velInfluence
    local velYaw  = math.sin(CurTime() * 1.6) * velFrac * (maxAng * 0.5)  * intensity
    local velPitch= math.cos(CurTime() * 1.2) * velFrac * (maxAng * 0.35) * intensity

    tgtPitch = tgtPitch + velPitch * 0.8
    tgtYaw   = tgtYaw   + velYaw   * 0.8

    local breath = math.sin(CurTime() * 1.4) * breathAmp * (1 - velFrac)
    tgtPitch = tgtPitch + breath * 0.25
    tgtYaw   = tgtYaw   + breath * 0.12

    -- NEW: more pronounced roll when NOT ADS
    local tgtRoll = 0
    if not ads then
        tgtRoll = (-mx / 60) * intensity * globalMul -- subtle roll when hip firing
        tgtRoll = math.Clamp(tgtRoll, -maxAng, maxAng)
    end
    tgtRoll = tgtRoll * adsRollScale

    -- Positional sway
    local tgtPosX = (-tgtYaw)   * 0.02 * maxPos
    local tgtPosY = ( tgtPitch) * 0.02 * maxPos
    local tgtPosZ = (breath * 0.01) * maxPos

    tgtPosX = tgtPosX * adsPosScale
    tgtPosY = tgtPosY * adsPosScale
    tgtPosZ = tgtPosZ * adsPosScale

    -- Springs
    local kA = 200 * smoothness
    local dA = 30  * smoothness

    local kP = 260 * smoothness
    local dP = 28  * smoothness

    st.targetPitch, st.angSpringVel.x = SpringApproach(st.targetPitch, st.angSpringVel.x, tgtPitch, kA, dA, dt)
    st.targetYaw,   st.angSpringVel.y = SpringApproach(st.targetYaw,   st.angSpringVel.y, tgtYaw,   kA, dA, dt)
    st.targetRoll,  st.angSpringVel.z = SpringApproach(st.targetRoll,  st.angSpringVel.z, tgtRoll,  kA, dA, dt)

    local cp = st.targetPos
    local pv = st.posSpringVel

    cp.x, pv.x = SpringApproach(cp.x, pv.x, tgtPosX, kP, dP, dt)
    cp.y, pv.y = SpringApproach(cp.y, pv.y, tgtPosY, kP, dP, dt)
    cp.z, pv.z = SpringApproach(cp.z, pv.z, tgtPosZ, kP, dP, dt)

    st.targetPos = cp
    st.posSpringVel = pv

    local ang = Angle(oldAng)
    ang:RotateAroundAxis(ang:Right(),  st.targetPitch)
    ang:RotateAroundAxis(ang:Up(),     st.targetYaw)
    ang:RotateAroundAxis(ang:Forward(),st.targetRoll)

    local pos = oldPos + ang:Right()*cp.x + ang:Forward()*cp.y + ang:Up()*cp.z

    return pos, ang
end)

concommand.Add("ls_sway_toggle", function()
    local c = CV("enable")
    c:SetBool(not c:GetBool())
    chat.AddText(Color(200,200,255), "[Sway] ", Color(255,255,255),
        "Sway is now: ", c:GetBool() and "ON" or "OFF")
end)
