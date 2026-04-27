import "phoenix_html";
import {Socket} from "phoenix";
import {LiveSocket} from "phoenix_live_view";
import * as DuskmoonHooks from "../../../../deps/phoenix_duskmoon/assets/js/hooks/index.js";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  hooks: DuskmoonHooks,
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
window.liveSocket = liveSocket;
