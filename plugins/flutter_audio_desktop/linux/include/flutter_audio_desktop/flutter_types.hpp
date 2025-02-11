#include <map>
#include <string>

#include <flutter_linux/flutter_linux.h>

class Method {
  public:
    std::string name;
    FlMethodResponse *response;
    FlMethodCall *methodCall = nullptr;

    Method(FlMethodCall *methodCall) {
        this->methodCall = methodCall;
        this->name = std::string(fl_method_call_get_name(methodCall));
    }

    template <class T> void returnValue(T result);

    void returnNull() {
        this->response = FL_METHOD_RESPONSE(
            fl_method_success_response_new(fl_value_new_null()));
    }

    void returnNotImplemented() {
        this->response =
            FL_METHOD_RESPONSE(fl_method_not_implemented_response_new());
    }

    template <class T> T getArgument(const char *argument);

    void returnResult() {
        fl_method_call_respond(this->methodCall, this->response, nullptr);
    }
};

template <> inline void Method::returnValue<int>(int result) {
    this->response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_int(result)));
}

template <> inline void Method::returnValue<std::string>(std::string result) {
    const char *resultCString = result.c_str();
    this->response = FL_METHOD_RESPONSE(
        fl_method_success_response_new(fl_value_new_string(resultCString)));
}

template <>
inline void Method::returnValue<std::map<std::string, std::string>>(
    std::map<std::string, std::string> result) {
    FlValue *map = fl_value_new_map();
    for (const auto &pair : result) {
        fl_value_set_string_take(map, pair.first.c_str(),
                                 fl_value_new_string(pair.second.c_str()));
    }
    this->response = FL_METHOD_RESPONSE(fl_method_success_response_new(map));
}

template <> inline int Method::getArgument<int>(const char *argument) {
    return fl_value_get_int(
        fl_value_lookup(fl_method_call_get_args(this->methodCall),
                        fl_value_new_string(argument)));
}

template <>
inline std::string Method::getArgument<std::string>(const char *argument) {
    return std::string(fl_value_get_string(
        fl_value_lookup(fl_method_call_get_args(this->methodCall),
                        fl_value_new_string(argument))));
}

template <> inline float Method::getArgument<float>(const char *argument) {
    return fl_value_get_float(
        fl_value_lookup(fl_method_call_get_args(this->methodCall),
                        fl_value_new_string(argument)));
}
