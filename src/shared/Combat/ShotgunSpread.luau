local ShotgunSpread = {}

function ShotgunSpread.GenerateDirections(forward, pelletCount, halfAngleDegrees, seed, guaranteedCenterPellets)
	local unitForward = forward.Unit
	local reference = if math.abs(unitForward.Y) < 0.99 then Vector3.yAxis else Vector3.xAxis
	local right = unitForward:Cross(reference).Unit
	local up = right:Cross(unitForward).Unit
	local cosineLimit = math.cos(math.rad(halfAngleDegrees))
	local random = Random.new(seed)
	local directions = table.create(pelletCount)
	for index = 1, pelletCount do
		if index <= (guaranteedCenterPellets or 0) then
			directions[index] = unitForward
			continue
		end
		local cosine = 1 - random:NextNumber() * (1 - cosineLimit)
		local sine = math.sqrt(math.max(0, 1 - cosine * cosine))
		local azimuth = random:NextNumber() * math.pi * 2
		directions[index] = (
			unitForward * cosine
			+ right * (math.cos(azimuth) * sine)
			+ up * (math.sin(azimuth) * sine)
		).Unit
	end
	return directions
end

return ShotgunSpread
