#include "include/flutter_audio_desktop/flutter_audio_desktop_plugin.h"
#include <windows.h>
#include <flutter/method_channel.h>
#include <flutter/plugin_registrar_windows.h>
#include <flutter/standard_method_codec.h>


#include "include/flutter_audio_desktop/flutter_types.hpp"
#include "../audioplayer/main.cpp"


namespace {

    class FlutterAudioDesktopPlugin : public flutter::Plugin {
        public:
        static void RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar);
        FlutterAudioDesktopPlugin();
        virtual ~FlutterAudioDesktopPlugin();

        private:
        void HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &method_call, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result);
    };

    void FlutterAudioDesktopPlugin::RegisterWithRegistrar(flutter::PluginRegistrarWindows *registrar) {
        auto channel = std::make_unique<flutter::MethodChannel<flutter::EncodableValue>>(registrar->messenger(), "flutter_audio_desktop", &flutter::StandardMethodCodec::GetInstance());
        auto plugin = std::make_unique<FlutterAudioDesktopPlugin>();
        channel->SetMethodCallHandler(
            [plugin_pointer = plugin.get()](const auto &call, auto result) {
            plugin_pointer->HandleMethodCall(call, std::move(result));
        });
        registrar->AddPlugin(std::move(plugin));
    }

    FlutterAudioDesktopPlugin::FlutterAudioDesktopPlugin() {}

    FlutterAudioDesktopPlugin::~FlutterAudioDesktopPlugin() {}

    void FlutterAudioDesktopPlugin::HandleMethodCall(const flutter::MethodCall<flutter::EncodableValue> &methodCall, std::unique_ptr<flutter::MethodResult<flutter::EncodableValue>> result) {
        Method method(&methodCall, std::move(result));
        if (method.name == "load") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            std::string filePath = method.getArgument<std::string>("filePath");
            AudioPlayer* audioPlayer = audioPlayers->get(id, deviceId);
            audioPlayer->load(filePath);
            method.returnNull();
        }
        else if (method.name == "play") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            audioPlayer->play();
            method.returnNull();
        }
        else if (method.name == "pause") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            audioPlayer->pause();
            method.returnNull();
        }
        else if (method.name == "stop") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            audioPlayer->stop();
            method.returnNull();
        }
        else if (method.name == "getPosition") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            int audioPlayerPosition = audioPlayer->getPosition();
            method.returnValue<int>(audioPlayerPosition);
        }
        else if (method.name == "getDuration") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            int audioPlayerDuration = audioPlayer->getDuration();
            method.returnValue<int>(audioPlayerDuration);
        }
        else if (method.name == "setPosition") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            int position = method.getArgument<int>("position");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            audioPlayer->setPosition(position);
            method.returnNull();
        }
        else if (method.name == "setVolume") {
            int id = method.getArgument<int>("id");
            std::string deviceId = method.getArgument<std::string>("deviceId");
            float volume = method.getArgument<float>("volume");
            AudioPlayer* audioPlayer = audioPlayers->get(id);
            audioPlayer->setVolume(volume);
            method.returnNull();
        }
        else if (method.name == "getDevices") {
            std::map<std::string, std::string> devicesMap = AudioDevices::getAllMap();
            method.returnValue<std::map<std::string, std::string>>(devicesMap);
        }
        else {
            method.returnNotImplemented();
        }
        method.returnResult();
    }
}


void FlutterAudioDesktopPluginRegisterWithRegistrar(FlutterDesktopPluginRegistrarRef registrar) {
    FlutterAudioDesktopPlugin::RegisterWithRegistrar(
        flutter::PluginRegistrarManager::GetInstance()->GetRegistrar<flutter::PluginRegistrarWindows>(registrar)
    );
}
