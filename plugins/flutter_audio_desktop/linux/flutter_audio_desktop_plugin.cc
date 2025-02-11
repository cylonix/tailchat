#include "include/flutter_audio_desktop/flutter_audio_desktop_plugin.h"
#include "flutter_linux/flutter_linux.h"
#include <gtk/gtk.h>
#include <sys/utsname.h>

#include "include/flutter_audio_desktop/flutter_types.hpp"
#include "../audioplayer/main.cpp"

#define FLUTTER_AUDIO_DESKTOP_PLUGIN(obj) (G_TYPE_CHECK_INSTANCE_CAST((obj), flutter_audio_desktop_plugin_get_type(), FlutterAudioDesktopPlugin))

struct _FlutterAudioDesktopPlugin {
    GObject parent_instance;
};

G_DEFINE_TYPE(FlutterAudioDesktopPlugin, flutter_audio_desktop_plugin, g_object_get_type())

static void flutter_audio_desktop_plugin_handle_method_call(FlutterAudioDesktopPlugin *self, FlMethodCall *method_call) {
    Method method(method_call);
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

static void flutter_audio_desktop_plugin_dispose(GObject *object) {
    G_OBJECT_CLASS(flutter_audio_desktop_plugin_parent_class)->dispose(object);
}

static void flutter_audio_desktop_plugin_class_init(FlutterAudioDesktopPluginClass *klass) {
    G_OBJECT_CLASS(klass)->dispose = flutter_audio_desktop_plugin_dispose;
}

static void flutter_audio_desktop_plugin_init(FlutterAudioDesktopPlugin *self) {
    AudioDevices::getAll();
    std::cout << __title__ << std::endl << 'v' << __version__ << std::endl;
}

static void method_call_cb(FlMethodChannel *channel, FlMethodCall *method_call, gpointer user_data) {
    FlutterAudioDesktopPlugin *plugin = FLUTTER_AUDIO_DESKTOP_PLUGIN(user_data);
    flutter_audio_desktop_plugin_handle_method_call(plugin, method_call);
}

void flutter_audio_desktop_plugin_register_with_registrar(FlPluginRegistrar *registrar) {
    FlutterAudioDesktopPlugin *plugin = FLUTTER_AUDIO_DESKTOP_PLUGIN(g_object_new(flutter_audio_desktop_plugin_get_type(), nullptr));
    g_autoptr(FlStandardMethodCodec) codec = fl_standard_method_codec_new();
    g_autoptr(FlMethodChannel) channel = fl_method_channel_new(
        fl_plugin_registrar_get_messenger(registrar),
        "flutter_audio_desktop",
        FL_METHOD_CODEC(codec)
    );
    fl_method_channel_set_method_call_handler(
        channel,
        method_call_cb,
        g_object_ref(plugin),
        g_object_unref
    );
    g_object_unref(plugin);
}
