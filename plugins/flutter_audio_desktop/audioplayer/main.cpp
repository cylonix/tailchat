#include <map>
#include <iostream>

#include "audioplayer.hpp"


class AudioPlayers {
    public:
    AudioPlayers() {
        this->audioDevices = AudioDevices::getAll();
    }

    AudioPlayer* get(int id, std::string deviceId = "default") {
        if (this->audioPlayers.find(id) == this->audioPlayers.end()) {
            AudioDevice* preferredAudioDevice = nullptr;
            if (deviceId != "default") {
                for (AudioDevice* audioDevice: this->audioDevices) {
                    if (std::to_string(audioDevice->id) == deviceId) {
                        preferredAudioDevice = audioDevice;
                        break;
                    };
                }
            }
            this->audioPlayers[id] = new AudioPlayer(preferredAudioDevice);
        }
        return this->audioPlayers[id];
    }

    private:
    std::map<int, AudioPlayer*> audioPlayers;
    std::vector<AudioDevice*> audioDevices;
};


AudioPlayers* audioPlayers = new AudioPlayers();


int main(int argc, const char **argv) {
    try {
        AudioDevices::getDefault();
        AudioPlayer* audioPlayer = audioPlayers->get(0);
        audioPlayer->load(argv[1]);
        audioPlayer->play();
        std::cin.get();
    }
    catch (std::string exception) {
        std::cout << exception << std::endl;
    }
    return 0;
}