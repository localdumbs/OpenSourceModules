local AudioStuff = script.AudioStuff
local soundModule = {}
local activeSounds = {}

export type AudioEffects = {
	Reverb: {
		Enabled: boolean?,
		Decay: number?,
		Density: number?,
		Diffusion: number?,
		DryLevel: number?,
		WetLevel: number?,
	}?,
	Equalizer: {
		Enabled: boolean?,
		LowGain: number?,
		MidGain: number?,
		HighGain: number?,
	}?,
	Distortion: {
		Enabled: boolean?,
		Level: number?,
	}?,
	Chorus: {
		Enabled: boolean?,
		Depth: number?,
		Mix: number?,
		Rate: number?,
	}?,
	Flange: {
		Enabled: boolean?,
		Depth: number?,
		Mix: number?,
		Rate: number?,
	}?,
	PitchShift: {
		Enabled: boolean?,
		Octave: number?,
	}?,
	Compress: {
		Enabled: boolean?,
		Threshold: number?,
		GainMakeup: number?,
		Attack: number?,
		Release: number?,
	}?,
}

export type SoundOptions = {
	Volume: number?,
	Pitch: number?,
	Looped: boolean?,
	DelayTime: number?,
	FadeIn: number?,
	FadeOut: number?,
	Effects: AudioEffects?,
	OnEnded: (() -> ())?
}

local EFFECT_DEFAULTS = {
	Reverb = {
		ClassName = "ReverbSoundEffect",
		Props = {
			Decay = 1.5,
			Density = 1,
			Diffusion = 1,
			DryLevel = -6,
			WetLevel = -6,
		}
	},
	Equalizer = {
		ClassName = "EqualizerSoundEffect",
		Props = {
			LowGain = 0,
			MidGain = 0,
			HighGain = 0,
		}
	},
	Distortion = {
		ClassName = "DistortionSoundEffect",
		Props = {
			Level = 0.5,
		}
	},
	Chorus = {
		ClassName = "ChorusSoundEffect",
		Props = {
			Depth = 0.5,
			Mix = 0.5,
			Rate = 0.5,
		}
	},
	Flange = {
		ClassName = "FlangeSoundEffect",
		Props = {
			Depth = 0.45,
			Mix = 0.45,
			Rate = 0.45,
		}
	},
	PitchShift = {
		ClassName = "PitchShiftSoundEffect",
		Props = {
			Octave = 0,
		}
	},
	Compress = {
		ClassName = "CompressorSoundEffect",
		Props = {
			Threshold = -16,
			GainMakeup = 0,
			Attack = 0.003,
			Release = 0.5,
		}
	},
}

local function applyEffects(sound: Sound, effects: AudioEffects)
	for effectName, effectOptions in pairs(effects) do
		local effectData = EFFECT_DEFAULTS[effectName]
		if not effectData then
			warn("[SoundModule] Unknown effect:", effectName)
			continue
		end

		if effectOptions.Enabled == false then
			continue
		end

		local effect = Instance.new(effectData.ClassName)

		for prop, default in pairs(effectData.Props) do
			effect[prop] = effectOptions[prop] ~= nil and effectOptions[prop] or default
		end

		effect.Parent = sound
	end
end

local function fadeVolume(sound: Sound, from: number, to: number, duration: number)
	sound.Volume = from
	local steps = 20
	local stepTime = duration / steps
	local volumeStep = (to - from) / steps

	for _ = 1, steps do
		task.wait(stepTime)
		sound.Volume = math.clamp(sound.Volume + volumeStep, 0, 10)
	end

	sound.Volume = to
end

function soundModule:Play(sound: string, soundPart: BasePart, options: SoundOptions)
	options = options or {}

	local newAudio = AudioStuff:Clone()
	local soundInstances = {}

	for _, v in ipairs(newAudio:GetChildren()) do
		if v:IsA("Sound") then
			v.SoundId = sound
			v.Volume = options.Volume or v.Volume
			v.PlaybackSpeed = options.Pitch or 1
			v.Looped = options.Looped or false

			if options.Effects then
				applyEffects(v, options.Effects)
			end

			v.Parent = soundPart
			table.insert(soundInstances, v)
			table.insert(activeSounds, v)
		else
			v.Parent = soundPart
		end
	end

	newAudio:Destroy()

	for _, soundInstance in ipairs(soundInstances) do
		local targetVolume = soundInstance.Volume

		if options.FadeIn then
			task.spawn(fadeVolume, soundInstance, 0, targetVolume, options.FadeIn)
			soundInstance:Play()
		else
			soundInstance:Play()
		end

		task.spawn(function()
			local duration = options.DelayTime or soundInstance.TimeLength
			if duration <= 0 then
				soundInstance.Ended:Wait()
			else
				task.wait(duration)
			end

			if options.FadeOut then
				fadeVolume(soundInstance, soundInstance.Volume, 0, options.FadeOut)
			end

			local index = table.find(activeSounds, soundInstance)
			if index then
				table.remove(activeSounds, index)
			end

			soundInstance:Destroy()

			if options.OnEnded then
				options.OnEnded()
			end
		end)
	end

	return soundInstances
end

function soundModule:AddEffect(soundPart: BasePart, effects: AudioEffects)
	for _, sound in ipairs(activeSounds) do
		if sound and sound.Parent == soundPart then
			applyEffects(sound, effects)
		end
	end
end

function soundModule:RemoveEffect(soundPart: BasePart, effectName: string)
	local effectData = EFFECT_DEFAULTS[effectName]
	if not effectData then
		warn("[SoundModule] Unknown effect:", effectName)
		return
	end

	for _, sound in ipairs(activeSounds) do
		if sound and sound.Parent == soundPart then
			for _, child in ipairs(sound:GetChildren()) do
				if child.ClassName == effectData.ClassName then
					child:Destroy()
				end
			end
		end
	end
end

function soundModule:StopAll()
	for _, sound in ipairs(activeSounds) do
		if sound and sound.Parent then
			sound:Stop()
			sound:Destroy()
		end
	end
	activeSounds = {}
end

function soundModule:StopAt(soundPart: BasePart)
	for i = #activeSounds, 1, -1 do
		local sound = activeSounds[i]
		if sound and sound.Parent == soundPart then
			sound:Stop()
			sound:Destroy()
			table.remove(activeSounds, i)
		end
	end
end

function soundModule:SetVolumeAt(soundPart: BasePart, volume: number)
	for _, sound in ipairs(activeSounds) do
		if sound and sound.Parent == soundPart then
			sound.Volume = volume
		end
	end
end

function soundModule:GetActiveSounds()
	return activeSounds
end

return soundModule