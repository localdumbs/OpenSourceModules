local SoundService = {}
SoundService.__index = SoundService

--{{CONSTRUCTOR}}--
function SoundService.new(soundFolder: Instance, defaultParent: Instance?)
	local self = setmetatable({}, SoundService)

	self.SoundTemplates = {}
	self.Registered = {} 
	self.Pool = {}
	self.Active = {}
	self.Parent = defaultParent or workspace

	for _, sound in ipairs(soundFolder:GetChildren()) do
		if sound:IsA("Sound") then
			self.SoundTemplates[sound.Name] = sound
			self.Registered[sound.Name] = sound.SoundId
		end
	end

	return self
end

--{{REGISTER NEW SOUND}}--
function SoundService:Register(name: string, soundId: string)
	self.Registered[name] = soundId
end

--{{DROP SOUND}}--
function SoundService:Drop(name: string)
	self.Registered[name] = nil
	self.SoundTemplates[name] = nil

	for id, sound in pairs(self.Active) do
		if sound.Name == name then
			sound:Stop()
			self.Active[id] = nil
		end
	end

	for i = #self.Pool, 1, -1 do
		local sound = self.Pool[i]
		if sound.Name == name then
			sound:Destroy()
			table.remove(self.Pool, i)
		end
	end
end

--{{GET SOUND}}--
function SoundService:_getSound(name: string)
	local template = self.SoundTemplates[name]
	local soundId = self.Registered[name]

	if not template and not soundId then
		warn("[SoundService] Missing sound:", name)
		return nil
	end

	for _, sound in ipairs(self.Pool) do
		if not sound.IsPlaying and sound.Name == name then
			return sound
		end
	end

	local newSound = (template and template:Clone()) or Instance.new("Sound")
	newSound.Name = name
	newSound.SoundId = soundId or ""
	newSound.Parent = self.Parent

	table.insert(self.Pool, newSound)
	return newSound
end

--{{PLAY}}--
function SoundService:Play(name: string, options: table?)
	options = options or {}

	local sound = self:_getSound(name)
	if not sound then return nil end

	-- apply runtime overrides
	if options.SoundId then
		sound.SoundId = options.SoundId
	elseif self.Registered[name] then
		sound.SoundId = self.Registered[name]
	end

	if options.Volume then sound.Volume = options.Volume end
	if options.Pitch then sound.PlaybackSpeed = options.Pitch end
	if options.Parent then sound.Parent = options.Parent else sound.Parent = self.Parent end
	if options.Looped ~= nil then sound.Looped = options.Looped end

	local id = options.Id or (name .. "_" .. tostring(os.clock()))
	self.Active[id] = sound

	if not sound.Looped then
		task.spawn(function()
			sound.Ended:Wait()
			if self.Active[id] == sound then
				self.Active[id] = nil
			end
		end)
	end

	sound:Play()
	return id
end

--{{CONTROL}}--
function SoundService:Stop(id: string)
	local sound = self.Active[id]
	if sound then
		sound:Stop()
		self.Active[id] = nil
	end
end

function SoundService:Pause(id: string)
	local sound = self.Active[id]
	if sound then
		sound:Pause()
	end
end

function SoundService:Resume(id: string)
	local sound = self.Active[id]
	if sound and sound.IsPaused then
		sound:Play()
	end
end

function SoundService:SetParent(id: string, newParent: Instance)
	local sound = self.Active[id]
	if sound then
		sound.Parent = newParent
	end
end

--{{UTIL}}--
function SoundService:StopAll()
	for id, sound in pairs(self.Active) do
		sound:Stop()
	end
	table.clear(self.Active)
end

return SoundService
