#define MINIAUDIO_IMPLEMENTATION
#include <thread>
#include <iostream>
#include <vector>
#include <string>

#include "miniaudio/miniaudio.h"

#include "internal/audiodevices.hpp"
#include "internal/callbacks.hpp"


const std::string __title__   = "flutter_audio_desktop";
const std::string __author__  = "alexmercerind";
const std::string __license__ = "MIT";
const std::string __version__ = "0.0.9";


class AudioPlayerInternal {
    protected:
    std::vector<AudioDevice*> audioDevices;
    AudioDevice* preferredAudioDevice;
    AudioDevice* defaultAudioDevice;
    ma_device device;
    ma_resource_manager resourceManager;
    ma_resource_manager_data_source dataSource;
    bool isLoaded = false;
    
    void initialize() {
        this->audioDevices = AudioDevices::getAll();
        this->defaultAudioDevice = AudioDevices::getDefault();
        this->initDevice(
            this->preferredAudioDevice == nullptr ? this->defaultAudioDevice: this->preferredAudioDevice
        );
        this->initResourceManager();
    }

    void uninitialize() {
        ma_device_uninit(&this->device);
        ma_resource_manager_data_source_uninit(&this->dataSource);
        ma_resource_manager_uninit(&this->resourceManager);
        ma_context_uninit(&deviceContext);
    }

    private:
    ma_device_config deviceConfig;
    ma_resource_manager_config resourceManagerConfig;

    void initDevice(AudioDevice* audioDevice) {
        this->deviceConfig = ma_device_config_init(ma_device_type_playback);
        this->deviceConfig.dataCallback = dataCallbackStream;
        this->deviceConfig.playback.pDeviceID = &audioDevice->info.id;
        this->deviceConfig.pUserData = &this->dataSource;
        ma_device_init(&deviceContext, &this->deviceConfig, &this->device);
    }

    void initResourceManager() {
        this->resourceManagerConfig = ma_resource_manager_config_init();
        this->resourceManagerConfig.decodedFormat     = this->device.playback.format;
        this->resourceManagerConfig.decodedChannels   = this->device.playback.channels;
        this->resourceManagerConfig.decodedSampleRate = this->device.sampleRate;
        ma_resource_manager_init(&resourceManagerConfig, &resourceManager);
    }
};


class AudioPlayer: protected AudioPlayerInternal {
    public:
    AudioPlayer(AudioDevice* audioDevice) {
        this->preferredAudioDevice = audioDevice;
    };

    void play(bool isLooping = false) {
        if (this->isLoaded) {
            ma_resource_manager_data_source_set_looping(&this->dataSource, isLooping);
            ma_device_start(&this->device);
        }
    }

    void pause() {
        ma_device_stop(&this->device);
    }

    void load(std::string filePath) {
        this->isLoaded = true;
        this->initialize();
        ma_resource_manager_data_source_init(
            &this->resourceManager,
            filePath.c_str(),
            MA_RESOURCE_MANAGER_DATA_SOURCE_FLAG_STREAM,
            NULL,
            &this->dataSource
        );
    }

    void stop() {
        if (this->isLoaded) {
            this->uninitialize();
        }
        this->isLoaded = false;
    }

    void setVolume(float volume) {
        if (this->isLoaded) {
            ma_device_set_master_volume(&this->device, volume);
        }
    }

    void setPosition(int durationMilliseconds) {
        if (this->isLoaded) {
            uint32_t durationPCMFrame = ma_calculate_buffer_size_in_frames_from_milliseconds(durationMilliseconds, this->device.sampleRate);
            ma_resource_manager_data_source_seek_to_pcm_frame(&this->dataSource, durationPCMFrame);
        }
    }

    int getDuration() {
        if (this->isLoaded) {
            unsigned long long durationPCMFrame;
            ma_resource_manager_data_source_get_length_in_pcm_frames(
                &this->dataSource,
                &durationPCMFrame
            );
            uint32_t duration = ma_calculate_buffer_size_in_milliseconds_from_frames(
                static_cast<uint32_t>(durationPCMFrame),
                this->device.sampleRate
            );
            return static_cast<int>(duration);
        }
        else return 0;
    }

    int getPosition() {
        if (this->isLoaded) {
            unsigned long long positionPCMFrame;
            ma_resource_manager_data_source_get_cursor_in_pcm_frames(
                &this->dataSource,
                &positionPCMFrame
            );
            uint32_t position = ma_calculate_buffer_size_in_milliseconds_from_frames(
                static_cast<uint32_t>(positionPCMFrame),
                this->device.sampleRate
            );
            return static_cast<int>(position);
        }
        else return 0;
    }
};
