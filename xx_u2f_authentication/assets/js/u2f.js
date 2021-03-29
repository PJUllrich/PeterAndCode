import { u2f } from "./u2f-api";

const Registration = {
  mounted() {
    this.handleEvent(
      "register",
      ({
        appId: appId,
        registerRequests: registerRequests,
        username: username,
      }) => {
        u2f.register(appId, registerRequests, [], (deviceResponse) => {
          this.pushEvent("finish_registration", {
            response: deviceResponse,
            username: username,
          });
        });
      }
    );
  },
};

const Login = {
  mounted() {
    this.handleEvent(
      "login",
      ({
        appId: appId,
        challenge: challenge,
        registeredKeys: registeredKeys,
        username: username,
      }) => {
        u2f.sign(appId, challenge, registeredKeys, (deviceResponse) => {
          this.pushEvent("finish_login", {
            response: deviceResponse,
            username: username,
          });
        });
      }
    );
  },
};

export { Registration, Login };
