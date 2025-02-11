#include <vector>
#include <map>
#include <string>

#include "../miniaudio/miniaudio.h"


class AudioDevice {
    public:
    int id;
    ma_device_info info;

    AudioDevice(int index, ma_device_info info) {
        this->id = index;
        this->info = info;
    }
};

ma_context deviceContext;

class AudioDevices {
    public:
    static std::vector<AudioDevice*> getAll() {
        std::vector<AudioDevice*> audioDevices;
        bool success = true;
        if (ma_context_init(NULL, 0, NULL, &deviceContext) != 0) {
            success = false;
        }
        ma_device_info *playbackDeviceInfos;
        unsigned int playbackDeviceCount;
        if (ma_context_get_devices(&deviceContext, &playbackDeviceInfos, &playbackDeviceCount, NULL, NULL) != 0) {
            success = false;
        }
        for (uint32_t index = 0; index < playbackDeviceCount; index++) {
            AudioDevice* device = new AudioDevice(
                index,
                playbackDeviceInfos[index]
            );
            audioDevices.push_back(device);
        }
        if (!success) {
            throw std::string("EXCEPTION: Audio devices could not be found.");
        }
        return audioDevices;
    }

    static AudioDevice* getDefault() {
        std::vector<AudioDevice*> audioDevices = AudioDevices::getAll();
        AudioDevice* defaultAudioDevice = audioDevices[0];
        for (AudioDevice* audioDevice: audioDevices) {
            if (audioDevice->info.isDefault) {
                defaultAudioDevice = audioDevice;
                break;
            };
        }
        return defaultAudioDevice;
    }

    static std::map<std::string, std::string> getAllMap() {
        std::map<std::string, std::string> devices;
        for (AudioDevice* device: AudioDevices::getAll()) {
            devices[std::to_string(device->id)] = device->info.name;
        }
        devices["default"] = AudioDevices::getDefault()->info.name;
        return devices;
    }
};


enum PlaybackState {
    deviceFind,
    deviceInit,
    resourceManagerInit,
    dataSourceInit,
    deviceStart,
};
