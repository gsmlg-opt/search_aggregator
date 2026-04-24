import {Socket} from "/assets/vendor/phoenix.mjs";
import {LiveSocket} from "/assets/vendor/phoenix_live_view.esm.js";

const csrfToken = document
  .querySelector("meta[name='csrf-token']")
  .getAttribute("content");

const liveSocket = new LiveSocket("/live", Socket, {
  params: {_csrf_token: csrfToken}
});

liveSocket.connect();
window.liveSocket = liveSocket;

document.querySelectorAll("[role=alert][data-flash]").forEach((element) => {
  element.addEventListener("click", () => {
    element.setAttribute("hidden", "");
  });
});
