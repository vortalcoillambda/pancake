function SWEP:PlayAnim(act, speed)
	local vmodel = self:GetOwner():GetViewModel()
	local seq = isstring(act) and self:LookupSequence(act) or vmodel:SelectWeightedSequence(act)

	if not seq or seq == -1 then
		return longsword.debugPrint("Attempting to play invalid sequence " .. act .. "!")
	end
	
	vmodel:ResetSequenceInfo()
	vmodel:SendViewModelMatchingSequence(seq)

	if speed then
		vmodel:SetPlaybackRate(speed)
	end

	return vmodel:SequenceDuration(seq) / (speed or 1)
end

function SWEP:PlayAnimWorld(act)
	local wmodel = self
	local seq = wmodel:SelectWeightedSequence(act)

	self:ResetSequence(seq)
end

function SWEP:QueueIdle(duration)
	if not duration then
		duration = self:GetOwner():GetViewModel():SequenceDuration()
	end

	self:SetNextIdle( CurTime() + duration + 0.1 )
end