import handleRequest from "../server/app.js";

export default {
  fetch(request, env, context) {
    return handleRequest(request, { env, context });
  },
};
