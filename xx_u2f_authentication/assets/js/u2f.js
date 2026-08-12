import u2fApi from "u2f-api";

const Registration = {
  mounted() {
    this.handleEvent("register", ({ registerRequests }) => {
      u2fApi.register(registerRequests).then((deviceResponse) => {
        this.pushEvent("finish_registration", { response: deviceResponse });
      });
    });
  },
};

const Login = {
  mounted() {
    this.handleEvent("login", ({ signRequests }) => {
      u2fApi.sign(signRequests).then((deviceResponse) => {
        this.pushEvent("finish_login", { response: deviceResponse });
      });
    });
  },
};

export { Registration, Login };
