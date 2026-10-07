import { InteractiveMode } from "./interactive_mode.js";
import { RpcClient } from "./rpc_client.js";

const agent = new RpcClient();
new InteractiveMode(agent).run();
