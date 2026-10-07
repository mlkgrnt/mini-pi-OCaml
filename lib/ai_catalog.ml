(* Built-in provider catalog. GENERATED -- do not edit by hand.
 *
 *   python tools/gen_providers.py [--fetch]
 *
 * Source: https://models.dev/api.json (snapshot at .deps/models.dev.api.json).
 *   providers: 54   models: 478
 *
 * Every entry speaks OpenAI Chat Completions, which is the only wire format
 * this port implements. Base URLs and model metadata are taken from the source
 * above; where a provider's URL is not in it, the documentation that states
 * the URL is named in [doc]. The rules, and the providers left out, are in
 * tools/gen_providers.py. *)

let providers : Ai_catalog_spec.provider list = [
  {
    Ai_catalog_spec.id = "openai";
    label = "OpenAI";
    base_url = "https://api.openai.com/v1";
    env = [ "OPENAI_API_KEY" ];
    doc = "https://platform.openai.com/docs/models";
    models = [
      {
        Ai_catalog_spec.id = "gpt-6.1-sol";
        label = "GPT-6.1 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-luna";
        label = "GPT-6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-sol";
        label = "GPT-6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-astra";
        label = "GPT-6 Astra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-daybreak-blue-latest";
        label = "Daybreak Blue";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6";
        label = "GPT-5.6";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-luna";
        label = "GPT-5.6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-terra";
        label = "GPT-5.6 Terra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-sol";
        label = "GPT-5.6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.5-pro";
        label = "GPT-5.5 Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.5";
        label = "GPT-5.5";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.4";
        label = "GPT-5.4";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "anthropic";
    label = "Anthropic";
    base_url = "https://api.anthropic.com/v1";
    env = [ "ANTHROPIC_API_KEY" ];
    doc = "https://docs.anthropic.com/en/docs/about-claude/models";
    models = [
      {
        Ai_catalog_spec.id = "claude-sonnet-5-5";
        label = "Claude Sonnet 5.5";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-opus-5-5";
        label = "Claude Opus 5.5";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-fable-5-1";
        label = "Claude Fable 5.1";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-opus-5";
        label = "Claude Opus 5";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-sonnet-5";
        label = "Claude Sonnet 5";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-fable-5";
        label = "Claude Fable 5";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-opus-4-8";
        label = "Claude Opus 4.8";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-opus-4-7";
        label = "Claude Opus 4.7";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-opus-4-6";
        label = "Claude Opus 4.6";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-sonnet-4-6";
        label = "Claude Sonnet 4.6";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-sonnet-4-5";
        label = "Claude Sonnet 4.5 (latest)";
        context_window = 1000000;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "claude-sonnet-4-5-20250929";
        label = "Claude Sonnet 4.5";
        context_window = 1000000;
        max_tokens = 64000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "google";
    label = "Google";
    base_url = "https://generativelanguage.googleapis.com/v1beta/openai";
    env = [ "GOOGLE_API_KEY"; "GOOGLE_GENERATIVE_AI_API_KEY"; "GEMINI_API_KEY" ];
    doc = "https://ai.google.dev/gemini-api/docs/models";
    models = [
      {
        Ai_catalog_spec.id = "gemini-3.8-flash";
        label = "Gemini 3.8 Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-flash-latest";
        label = "Gemini Flash Latest";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.7-flash";
        label = "Gemini 3.7 Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-flash-lite-latest";
        label = "Gemini Flash-Lite Latest";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.6-flash";
        label = "Gemini 3.6 Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.5-flash-lite";
        label = "Gemini 3.5 Flash Lite";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.5-flash";
        label = "Gemini 3.5 Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.1-flash-lite";
        label = "Gemini 3.1 Flash Lite";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.1-flash-lite-preview";
        label = "Gemini 3.1 Flash Lite Preview";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.1-pro-preview";
        label = "Gemini 3.1 Pro Preview";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.1-pro-preview-customtools";
        label = "Gemini 3.1 Pro Preview Custom Tools";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3-flash-preview";
        label = "Gemini 3 Flash Preview";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "xai";
    label = "xAI";
    base_url = "https://api.x.ai/v1";
    env = [ "XAI_API_KEY" ];
    doc = "https://docs.x.ai/docs/models";
    models = [
      {
        Ai_catalog_spec.id = "grok-4.3";
        label = "Grok 4.3";
        context_window = 1000000;
        max_tokens = 30000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-4.20-0309-reasoning";
        label = "Grok 4.20 (Reasoning)";
        context_window = 1000000;
        max_tokens = 30000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-4.7";
        label = "Grok 4.7";
        context_window = 500000;
        max_tokens = 500000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-4.6";
        label = "Grok 4.6";
        context_window = 500000;
        max_tokens = 500000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-4.5";
        label = "Grok 4.5";
        context_window = 500000;
        max_tokens = 500000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-build-0.1";
        label = "Grok Build 0.1";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "grok-4.20-0309-non-reasoning";
        label = "Grok 4.20 (Non-Reasoning)";
        context_window = 1000000;
        max_tokens = 30000;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "groq";
    label = "Groq";
    base_url = "https://api.groq.com/openai/v1";
    env = [ "GROQ_API_KEY" ];
    doc = "https://console.groq.com/docs/models";
    models = [
      {
        Ai_catalog_spec.id = "openai/gpt-oss-safeguard-20b";
        label = "Safety GPT OSS 20B";
        context_window = 131072;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen/qwen3.6-27b";
        label = "Qwen3.6 27B";
        context_window = 131072;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-oss-120b";
        label = "GPT OSS 120B";
        context_window = 131072;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-oss-20b";
        label = "GPT OSS 20B";
        context_window = 131072;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen/qwen3.8-27b";
        label = "Qwen3.8 27B";
        context_window = 131042;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "llama-3.3-70b-versatile";
        label = "Llama 3.3 70B";
        context_window = 131072;
        max_tokens = 32768;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "llama-3.1-8b-instant";
        label = "Llama 3.1 8B";
        context_window = 131072;
        max_tokens = 131072;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "mistral";
    label = "Mistral";
    base_url = "https://api.mistral.ai/v1";
    env = [ "MISTRAL_API_KEY" ];
    doc = "https://docs.mistral.ai/getting-started/models/";
    models = [
      {
        Ai_catalog_spec.id = "zai-glm-5-3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-glm-5-2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-large-4";
        label = "Mistral Large 4";
        context_window = 524288;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-medium-2604";
        label = "Mistral Medium 3.5";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-medium-latest";
        label = "Mistral Medium (latest)";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-small-latest";
        label = "Mistral Small (latest)";
        context_window = 262144;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-small-2603";
        label = "Mistral Small 4";
        context_window = 262144;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "magistral-medium-latest";
        label = "Magistral Medium (latest)";
        context_window = 128000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "devstral-2512";
        label = "Devstral 2";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "devstral-latest";
        label = "Devstral 2";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "mistral-large-latest";
        label = "Mistral Large (latest)";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "devstral-medium-latest";
        label = "Devstral 2 (latest)";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "cerebras";
    label = "Cerebras";
    base_url = "https://api.cerebras.ai/v1";
    env = [ "CEREBRAS_API_KEY" ];
    doc = "https://inference-docs.cerebras.ai/models/overview";
    models = [
      {
        Ai_catalog_spec.id = "qwen-3.8-27b";
        label = "Qwen3.8 27B";
        context_window = 131072;
        max_tokens = 40960;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-oss-120b";
        label = "GPT OSS 120B";
        context_window = 131072;
        max_tokens = 40960;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "togetherai";
    label = "Together AI";
    base_url = "https://api.together.ai/v1";
    env = [ "TOGETHER_API_KEY" ];
    doc = "https://docs.together.ai/docs/serverless-models";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4.1-Flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM-5.3-Flash";
        context_window = 1048575;
        max_tokens = 400000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1048575;
        max_tokens = 164000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.6-Plus";
        label = "Qwen3.6 Plus";
        context_window = 1000000;
        max_tokens = 500000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "thinkingmachines/Inkling";
        label = "Inkling";
        context_window = 524288;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMaxAI/MiniMax-M3";
        label = "MiniMax-M3";
        context_window = 524288;
        max_tokens = 250000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/nemotron-3-ultra-550b-a55b";
        label = "Nemotron 3 Ultra 550B A55B";
        context_window = 512300;
        max_tokens = 512300;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-397B-A17B";
        label = "Qwen3.5 397B A17B";
        context_window = 262144;
        max_tokens = 130000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "deepinfra";
    label = "Deep Infra";
    base_url = "https://api.deepinfra.com/v1/openai";
    env = [ "DEEPINFRA_API_KEY" ];
    doc = "https://deepinfra.com/models";
    models = [
      {
        Ai_catalog_spec.id = "XiaomiMiMo/MiMo-V2.6-Pro";
        label = "MiMo-V2.6-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "XiaomiMiMo/MiMo-V2.6-Flash";
        label = "MiMo-V2.6-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4.1-Flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-Vision-Exp";
        label = "DeepSeek V4 Flash Vision Exp";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "tencent/Hy4-preview";
        label = "Hy4 preview";
        context_window = 1048576;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM-5.3-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash";
        label = "DeepSeek V4 Flash";
        context_window = 1048576;
        max_tokens = 16384;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "deepseek";
    label = "DeepSeek";
    base_url = "https://api.deepseek.com";
    env = [ "DEEPSEEK_API_KEY" ];
    doc = "https://api-docs.deepseek.com/quick_start/pricing";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-v4-flash-vision-exp";
        label = "DeepSeek V4 Flash Vision Exp";
        context_window = 1000000;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1000000;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash";
        label = "DeepSeek V4 Flash";
        context_window = 1000000;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-pro";
        label = "DeepSeek V4 Pro";
        context_window = 1000000;
        max_tokens = 393216;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "moonshotai";
    label = "Moonshot AI";
    base_url = "https://api.moonshot.ai/v1";
    env = [ "MOONSHOT_API_KEY" ];
    doc = "https://platform.moonshot.ai/docs/api/chat";
    models = [
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.7-code-highspeed";
        label = "Kimi K2.7 Code HighSpeed";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.7-code";
        label = "Kimi K2.7 Code";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.6";
        label = "Kimi K2.6";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "moonshotai-cn";
    label = "Moonshot AI (China)";
    base_url = "https://api.moonshot.cn/v1";
    env = [ "MOONSHOT_API_KEY" ];
    doc = "https://platform.moonshot.cn/docs/api/chat";
    models = [
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.7-code";
        label = "Kimi K2.7 Code";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.7-code-highspeed";
        label = "Kimi K2.7 Code HighSpeed";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.6";
        label = "Kimi K2.6";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "zhipuai";
    label = "Zhipu AI";
    base_url = "https://open.bigmodel.cn/api/paas/v4";
    env = [ "ZHIPU_API_KEY" ];
    doc = "https://docs.z.ai/guides/overview/pricing";
    models = [
      {
        Ai_catalog_spec.id = "glm-5.3-flashx";
        label = "GLM-5.3-FlashX";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3-flash";
        label = "GLM-5.3-Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM-5.3";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5";
        label = "GLM-5";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7";
        label = "GLM-4.7";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.6";
        label = "GLM-4.6";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5v-turbo";
        label = "GLM-5V-Turbo";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.1";
        label = "GLM-5.1";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7-flashx";
        label = "GLM-4.7-FlashX";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7-flash";
        label = "GLM-4.7-Flash";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.5-air";
        label = "GLM-4.5-Air";
        context_window = 131072;
        max_tokens = 98304;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "zai";
    label = "Z.AI";
    base_url = "https://api.z.ai/api/paas/v4";
    env = [ "ZHIPU_API_KEY" ];
    doc = "https://docs.z.ai/guides/overview/pricing";
    models = [
      {
        Ai_catalog_spec.id = "glm-5.3-flashx";
        label = "GLM-5.3-FlashX";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3-flash";
        label = "GLM-5.3-Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM-5.3";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5";
        label = "GLM-5";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7";
        label = "GLM-4.7";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.6";
        label = "GLM-4.6";
        context_window = 204800;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.1";
        label = "GLM-5.1";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5v-turbo";
        label = "GLM-5V-Turbo";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5-turbo";
        label = "GLM-5-Turbo";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7-flash";
        label = "GLM-4.7-Flash";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-4.7-flashx";
        label = "GLM-4.7-FlashX";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "meta";
    label = "Meta";
    base_url = "https://api.meta.ai/v1";
    env = [ "META_MODEL_API_KEY" ];
    doc = "https://dev.meta.ai/docs";
    models = [
      {
        Ai_catalog_spec.id = "muse-spark-1.3";
        label = "Muse Spark 1.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "muse-spark-1.3-contributor";
        label = "Muse Spark 1.3 Contributor";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "muse-spark-1.2";
        label = "Muse Spark 1.2";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "muse-spark-1.2-contributor";
        label = "Muse Spark 1.2 Contributor";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "muse-spark-1.1";
        label = "Muse Spark 1.1";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "alibaba";
    label = "Alibaba";
    base_url = "https://dashscope-intl.aliyuncs.com/compatible-mode/v1";
    env = [ "DASHSCOPE_API_KEY" ];
    doc = "https://www.alibabacloud.com/help/en/model-studio/models";
    models = [
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-omni-flash";
        label = "Qwen3.8 Omni Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-flash";
        label = "Qwen3.8 Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-max";
        label = "Qwen3.8 Max";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-flash";
        label = "Qwen3.7 Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-plus";
        label = "Qwen3.7 Plus";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-max";
        label = "Qwen3.7 Max";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.6-flash";
        label = "Qwen3.6 Flash";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.6-plus";
        label = "Qwen3.6 Plus";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-flash";
        label = "Qwen3.5 Flash";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "alibaba-cn";
    label = "Alibaba (China)";
    base_url = "https://dashscope.aliyuncs.com/compatible-mode/v1";
    env = [ "DASHSCOPE_API_KEY" ];
    doc = "https://www.alibabacloud.com/help/en/model-studio/models";
    models = [
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-flash";
        label = "Qwen3.5 Flash";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-plus";
        label = "Qwen3.5 Plus";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-omni-flash";
        label = "Qwen3.8 Omni Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4.1-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-flash";
        label = "Qwen3.8 Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM-5.3";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-max";
        label = "Qwen3.8 Max";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-flash";
        label = "Qwen3.7 Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-plus";
        label = "Qwen3.7 Plus";
        context_window = 1000000;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.7-max";
        label = "Qwen3.7 Max";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "siliconflow";
    label = "SiliconFlow";
    base_url = "https://api.siliconflow.com/v1";
    env = [ "SILICONFLOW_API_KEY" ];
    doc = "https://cloud.siliconflow.com/models";
    models = [
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM-5.3-Flash";
        context_window = 1049000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM-5.3";
        context_window = 1049000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.8-2.4T-A95B";
        label = "Qwen3.8 2.4T A95B";
        context_window = 1049000;
        max_tokens = 131000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "meituan-longcat/LongCat-2.0";
        label = "LongCat-2.0";
        context_window = 1049000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1049000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMaxAI/MiniMax-M3";
        label = "MiniMax-M3";
        context_window = 1048576;
        max_tokens = 131000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-Vision-Exp";
        label = "DeepSeek V4 Flash Vision Exp";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash";
        label = "DeepSeek V4 Flash";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro";
        label = "DeepSeek V4 Pro";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "siliconflow-cn";
    label = "SiliconFlow (China)";
    base_url = "https://api.siliconflow.cn/v1";
    env = [ "SILICONFLOW_CN_API_KEY" ];
    doc = "https://cloud.siliconflow.com/models";
    models = [
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1049000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro";
        label = "deepseek-ai/DeepSeek-V4-Pro";
        context_window = 1049000;
        max_tokens = 393000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash";
        label = "DeepSeek V4 Flash";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-4B";
        label = "Qwen/Qwen3.5-4B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-9B";
        label = "Qwen/Qwen3.5-9B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-122B-A10B";
        label = "Qwen/Qwen3.5-122B-A10B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-27B";
        label = "Qwen/Qwen3.5-27B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-35B-A3B";
        label = "Qwen/Qwen3.5-35B-A3B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-397B-A17B";
        label = "Qwen/Qwen3.5-397B-A17B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Pro/moonshotai/Kimi-K2.6";
        label = "Pro/moonshotai/Kimi-K2.6";
        context_window = 262000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "stepfun-ai/Step-3.5-Flash";
        label = "stepfun-ai/Step-3.5-Flash";
        context_window = 262000;
        max_tokens = 262000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Pro/moonshotai/Kimi-K2.5";
        label = "Pro/moonshotai/Kimi-K2.5";
        context_window = 262000;
        max_tokens = 262000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "stepfun";
    label = "StepFun (China)";
    base_url = "https://api.stepfun.com/v1";
    env = [ "STEPFUN_API_KEY" ];
    doc = "https://platform.stepfun.com/docs/zh/overview/concept";
    models = [
      {
        Ai_catalog_spec.id = "step-5-preview";
        label = "Step 5 Preview";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.7-flash";
        label = "Step 3.7 Flash";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.5-flash";
        label = "Step 3.5 Flash";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.5-flash-2603";
        label = "Step 3.5 Flash 2603";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-1-32k";
        label = "Step 1 (32K)";
        context_window = 32768;
        max_tokens = 32768;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "step-2-16k";
        label = "Step 2 (16K)";
        context_window = 16384;
        max_tokens = 8192;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "stepfun-ai";
    label = "StepFun (Global)";
    base_url = "https://api.stepfun.ai/v1";
    env = [ "STEPFUN_API_KEY" ];
    doc = "https://platform.stepfun.ai/docs/en/overview/concept";
    models = [
      {
        Ai_catalog_spec.id = "step-5-preview";
        label = "Step 5 Preview";
        context_window = 1024000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.7-flash";
        label = "Step 3.7 Flash";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.5-flash";
        label = "Step 3.5 Flash";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-3.5-flash-2603";
        label = "Step 3.5 Flash 2603";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "step-1-32k";
        label = "Step 1 (32K)";
        context_window = 32768;
        max_tokens = 32768;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "step-2-16k";
        label = "Step 2 (16K)";
        context_window = 16384;
        max_tokens = 8192;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "xiaomi";
    label = "Xiaomi";
    base_url = "https://api.xiaomimimo.com/v1";
    env = [ "XIAOMI_API_KEY" ];
    doc = "https://platform.xiaomimimo.com/#/docs";
    models = [
      {
        Ai_catalog_spec.id = "mimo-v2.6-pro";
        label = "MiMo-V2.6-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.6-flash";
        label = "MiMo-V2.6-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.6-pro-ultraspeed";
        label = "MiMo-V2.6-Pro-UltraSpeed";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.5";
        label = "MiMo-V2.5";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2-pro";
        label = "MiMo-V2-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.5-pro";
        label = "MiMo-V2.5-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.5-pro-ultraspeed";
        label = "MiMo-V2.5-Pro-UltraSpeed";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2-flash";
        label = "MiMo-V2-Flash";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2-omni";
        label = "MiMo-V2-Omni";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "sensenova";
    label = "SenseNova (China)";
    base_url = "https://token.sensenova.cn/v1";
    env = [ "SENSENOVA_API_KEY" ];
    doc = "https://platform.sensenova.cn/docs";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-v4-pro";
        label = "DeepSeek V4 Pro";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash";
        label = "DeepSeek V4 Flash";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "sensenova-6.8-flash-lite";
        label = "SenseNova 6.8 Flash Lite";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "longcat";
    label = "LongCat";
    base_url = "https://api.longcat.chat/openai";
    env = [ "LONGCAT_API_KEY" ];
    doc = "https://longcat.chat/platform/docs/";
    models = [
      {
        Ai_catalog_spec.id = "LongCat-2.0";
        label = "LongCat-2.0";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "upstage";
    label = "Upstage";
    base_url = "https://api.upstage.ai/v1/solar";
    env = [ "UPSTAGE_API_KEY" ];
    doc = "https://developers.upstage.ai/docs/apis/chat";
    models = [
      {
        Ai_catalog_spec.id = "solar-pro4";
        label = "Solar Pro 4";
        context_window = 524288;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "solar-pro3";
        label = "solar-pro3";
        context_window = 131072;
        max_tokens = 8192;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "solar-pro2";
        label = "solar-pro2";
        context_window = 65536;
        max_tokens = 8192;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "solar-mini";
        label = "solar-mini";
        context_window = 32768;
        max_tokens = 4096;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "inception";
    label = "Inception";
    base_url = "https://api.inceptionlabs.ai/v1";
    env = [ "INCEPTION_API_KEY" ];
    doc = "https://docs.inceptionlabs.ai/get-started/models";
    models = [
      {
        Ai_catalog_spec.id = "mercury-2.5";
        label = "Mercury 2.5";
        context_window = 260000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mercury-2";
        label = "Mercury 2";
        context_window = 128000;
        max_tokens = 50000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "ai21";
    label = "AI21 Labs";
    base_url = "https://api.ai21.com/studio/v1";
    env = [ "AI21_API_KEY" ];
    doc = "https://docs.ai21.com/docs/jamba-foundation-models";
    models = [
      {
        Ai_catalog_spec.id = "jamba-mini";
        label = "Jamba Mini";
        context_window = 256000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "jamba-large";
        label = "Jamba Large";
        context_window = 256000;
        max_tokens = 4096;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "sakana";
    label = "Sakana AI";
    base_url = "https://api.sakana.ai/v1";
    env = [ "SAKANA_API_KEY" ];
    doc = "https://console.sakana.ai/models";
    models = [
      {
        Ai_catalog_spec.id = "fugu-ultra";
        label = "Fugu Ultra";
        context_window = 1000000;
        max_tokens = 1000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "fugu-ultra-20260615";
        label = "Fugu Ultra";
        context_window = 1000000;
        max_tokens = 1000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "fugu";
        label = "Fugu";
        context_window = 1000000;
        max_tokens = 1000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "sakana-namazu";
        label = "Sakana Namazu";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "arcee";
    label = "Arcee";
    base_url = "https://api.arcee.ai/api/v1";
    env = [ "ARCEE_API_KEY" ];
    doc = "https://docs.arcee.ai";
    models = [
      {
        Ai_catalog_spec.id = "deepseek/deepseek-v4-pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek/deepseek-v4-flash-latest";
        label = "DeepSeek V4 Flash Latest";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek/deepseek-v4-pro";
        label = "DeepSeek V4 Pro";
        context_window = 512000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "thinkingmachines/inkling-small";
        label = "Inkling Small";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/glm-5.2";
        label = "GLM-5.2";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "trinity-large-thinking";
        label = "Trinity Large Thinking";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "llama";
    label = "Llama";
    base_url = "https://api.llama.com/compat/v1";
    env = [ "LLAMA_API_KEY" ];
    doc = "https://llama.developer.meta.com/docs/models";
    models = [
      {
        Ai_catalog_spec.id = "llama-4-maverick-17b-128e-instruct-fp8";
        label = "Llama-4-Maverick-17B-128E-Instruct-FP8";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "groq-llama-4-maverick-17b-128e-instruct";
        label = "Groq-Llama-4-Maverick-17B-128E-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "llama-4-scout-17b-16e-instruct-fp8";
        label = "Llama-4-Scout-17B-16E-Instruct-FP8";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "cerebras-llama-4-maverick-17b-128e-instruct";
        label = "Cerebras-Llama-4-Maverick-17B-128E-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "cerebras-llama-4-scout-17b-16e-instruct";
        label = "Cerebras-Llama-4-Scout-17B-16E-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "llama-3.3-70b-instruct";
        label = "Llama-3.3-70B-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "llama-3.3-8b-instruct";
        label = "Llama-3.3-8B-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "nvidia";
    label = "Nvidia";
    base_url = "https://integrate.api.nvidia.com/v1";
    env = [ "NVIDIA_API_KEY" ];
    doc = "https://docs.api.nvidia.com/nim/";
    models = [
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "thinkingmachines/inkling";
        label = "Inkling";
        context_window = 1048576;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/deepseek-v4-pro";
        label = "DeepSeek V4 Pro";
        context_window = 1048576;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/deepseek-v4-flash";
        label = "DeepSeek V4 Flash";
        context_window = 1048576;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/deepseek-v4.1-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "z-ai/glm-5.3-flash";
        label = "GLM-5.3-Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/deepseek-v4-pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "z-ai/glm-5.3";
        label = "GLM-5.3";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/deepseek-v4-flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "z-ai/glm-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/nemotron-3-ultra-550b-a55b";
        label = "Nemotron 3 Ultra 550B A55B";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "minimaxai/minimax-m3";
        label = "MiniMax-M3";
        context_window = 1000000;
        max_tokens = 16384;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "tencent-tokenhub";
    label = "Tencent TokenHub";
    base_url = "https://tokenhub.tencentmaas.com/v1";
    env = [ "TENCENT_TOKENHUB_API_KEY" ];
    doc = "https://cloud.tencent.com/document/product/1823/130050";
    models = [
      {
        Ai_catalog_spec.id = "hy4-preview";
        label = "Hy4 preview";
        context_window = 1024000;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "hy3";
        label = "Hy3";
        context_window = 256000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "hy3-preview";
        label = "Hy3 preview";
        context_window = 256000;
        max_tokens = 64000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "volcengine";
    label = "Volcengine Ark";
    base_url = "https://ark.cn-beijing.volces.com/api/v3";
    env = [ "ARK_API_KEY" ];
    doc = "https://www.volcengine.com/docs/82379/1330310";
    models = [
      {
        Ai_catalog_spec.id = "glm-5-3-flash-260828";
        label = "GLM-5.3-Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-pro-ga-260813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash-ga-260731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1000000;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5-2-260617";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-0-code-preview-260215";
        label = "Seed 2.0 Code";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-1-pro-260628";
        label = "Seed 2.1 Pro";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-1-turbo-260628";
        label = "Seed 2.1 Turbo";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-evolving";
        label = "Seed Evolving";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-character-260628";
        label = "Seed Character";
        context_window = 256000;
        max_tokens = 256000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-0-pro-260215";
        label = "Seed 2.0 Pro";
        context_window = 256000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-0-lite-260428";
        label = "Seed 2.0 Lite";
        context_window = 256000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "doubao-seed-2-0-mini-260428";
        label = "Seed 2.0 Mini";
        context_window = 256000;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "qiniu-ai";
    label = "Qiniu";
    base_url = "https://api.qnaigc.com/v1";
    env = [ "QINIU_API_KEY" ];
    doc = "https://developer.qiniu.com/aitokenapi";
    models = [
      {
        Ai_catalog_spec.id = "x-ai/grok-4.1-fast-reasoning";
        label = "X-Ai/Grok 4.1 Fast Reasoning";
        context_window = 20000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "x-ai/grok-4-fast-reasoning";
        label = "X-Ai/Grok-4-Fast-Reasoning";
        context_window = 2000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "x-ai/grok-4.1-fast";
        label = "x-AI/Grok-4.1-Fast";
        context_window = 2000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "x-ai/grok-4-fast";
        label = "x-AI/Grok-4-Fast";
        context_window = 2000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-2.0-flash-lite";
        label = "Gemini 2.0 Flash Lite";
        context_window = 1048576;
        max_tokens = 8192;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-2.5-pro";
        label = "Gemini 2.5 Pro";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-2.5-flash";
        label = "Gemini 2.5 Flash";
        context_window = 1048576;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.0-flash-preview";
        label = "Gemini 3.0 Flash Preview";
        context_window = 1000000;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemini-3.0-pro-preview";
        label = "Gemini 3.0 Pro Preview";
        context_window = 1000000;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen-turbo";
        label = "Qwen-Turbo";
        context_window = 1000000;
        max_tokens = 4096;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMax-M1";
        label = "MiniMax M1";
        context_window = 1000000;
        max_tokens = 80000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.2";
        label = "OpenAI/GPT-5.2";
        context_window = 400000;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "modelscope";
    label = "ModelScope";
    base_url = "https://api-inference.modelscope.cn/v1";
    env = [ "MODELSCOPE_API_KEY" ];
    doc = "https://modelscope.cn/docs/model-service/API-Inference/intro";
    models = [
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-30B-A3B-Thinking-2507";
        label = "Qwen3 30B A3B Thinking 2507";
        context_window = 262144;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-235B-A22B-Thinking-2507";
        label = "Qwen3-235B-A22B-Thinking-2507";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "ZhipuAI/GLM-4.6";
        label = "GLM-4.6";
        context_window = 202752;
        max_tokens = 98304;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "ZhipuAI/GLM-4.5";
        label = "GLM-4.5";
        context_window = 131072;
        max_tokens = 98304;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-Coder-30B-A3B-Instruct";
        label = "Qwen3 Coder 30B A3B Instruct";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-30B-A3B-Instruct-2507";
        label = "Qwen3 30B A3B Instruct 2507";
        context_window = 262144;
        max_tokens = 16384;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-235B-A22B-Instruct-2507";
        label = "Qwen3 235B A22B Instruct 2507";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "baseten";
    label = "Baseten";
    base_url = "https://inference.baseten.co/v1";
    env = [ "BASETEN_API_KEY" ];
    doc = "https://docs.baseten.co/inference/model-apis/overview";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4.1-Flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4.1-Flash-Fast";
        label = "deepseek-ai/DeepSeek-V4.1-Flash-Fast";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM 5.3 Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Fast";
        label = "GLM 5.3 Fast";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM 5.3";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "thinkingmachines/inkling-small";
        label = "Inkling Small";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "thinkingmachines/inkling";
        label = "Inkling";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM 5.2";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2-Fast";
        label = "GLM 5.2 Fast";
        context_window = 1048576;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "nebius";
    label = "Nebius Token Factory";
    base_url = "https://api.tokenfactory.nebius.com/v1";
    env = [ "NEBIUS_API_KEY" ];
    doc = "https://docs.tokenfactory.nebius.com/";
    models = [
      {
        Ai_catalog_spec.id = "nvidia/Nemotron-3_5-Lightning";
        label = "Nemotron 3.5 Lightning 30B A3B";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 8000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/Nemotron-3-Ultra-550b-a55b";
        label = "Nemotron 3 Ultra 550B A55B";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMaxAI/MiniMax-M3";
        label = "MiniMax-M3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro";
        label = "DeepSeek V4 Pro";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4.1-Flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048000;
        max_tokens = 1048000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM-5.3-Flash";
        context_window = 1024000;
        max_tokens = 1024000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM-5.3";
        context_window = 1024000;
        max_tokens = 1024000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1024000;
        max_tokens = 1024000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 979000;
        max_tokens = 979000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.8-27B";
        label = "Qwen3.8 27B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "novita-ai";
    label = "NovitaAI";
    base_url = "https://api.novita.ai/openai";
    env = [ "NOVITA_API_KEY" ];
    doc = "https://novita.ai/docs/guides/introduction";
    models = [
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/glm-5.2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xiaomimimo/mimo-v2-pro";
        label = "MiMo-V2-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xiaomimimo/mimo-v2.5-pro";
        label = "MiMo-V2.5-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek/deepseek-v4-pro";
        label = "DeepSeek V4 Pro";
        context_window = 1048576;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek/deepseek-v4-flash";
        label = "DeepSeek V4 Flash";
        context_window = 1048576;
        max_tokens = 393216;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen/qwen3.7-max";
        label = "Qwen3.7-Max";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "minimaxai/minimax-m1-80k";
        label = "MiniMax M1";
        context_window = 1000000;
        max_tokens = 40000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k2-thinking";
        label = "Kimi K2 Thinking";
        context_window = 262144;
        max_tokens = 98304;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k2.7-code";
        label = "Kimi K2.7 Code";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "inclusionai/ring-2.6-1t";
        label = "Ring-2.6-1T";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k2.6";
        label = "Kimi K2.6";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "friendli";
    label = "Friendli";
    base_url = "https://api.friendli.ai/serverless/v1";
    env = [ "FRIENDLI_TOKEN" ];
    doc = "https://friendli.ai/docs/guides/serverless_endpoints/introduction";
    models = [
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3-Flash";
        label = "GLM-5.3-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemma-4-31B-it";
        label = "Gemma 4 31B IT";
        context_window = 262144;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.1";
        label = "GLM-5.1";
        context_window = 202752;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMaxAI/MiniMax-M2.5";
        label = "MiniMax-M2.5";
        context_window = 196608;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V3.2";
        label = "DeepSeek V3.2";
        context_window = 163840;
        max_tokens = 64000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "chutes";
    label = "Chutes";
    base_url = "https://llm.chutes.ai/v1";
    env = [ "CHUTES_API_KEY" ];
    doc = "https://llm.chutes.ai/v1/models";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash-0731-TEE";
        label = "DeepSeek V4 Flash 0731 TEE";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K3-TEE";
        label = "Kimi K3 TEE";
        context_window = 1048576;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2-TEE";
        label = "GLM 5.2 TEE";
        context_window = 1048576;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.8-27B-TEE";
        label = "Qwen3.8 27B TEE";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-235B-A22B-Thinking-2507-TEE";
        label = "Qwen3 235B A22B Thinking 2507 TEE";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.6-27B-TEE";
        label = "Qwen3.6 27B TEE";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K2.6-TEE";
        label = "Kimi K2.6 TEE";
        context_window = 262144;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.5-397B-A17B-TEE";
        label = "Qwen3.5 397B A17B TEE";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.1-TEE";
        label = "GLM 5.1 TEE";
        context_window = 202752;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V3.2-TEE";
        label = "DeepSeek V3.2 TEE";
        context_window = 131072;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemma-4-31B-turbo-TEE";
        label = "gemma 4 31B turbo TEE";
        context_window = 131072;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-32B-TEE";
        label = "Qwen3 32B TEE";
        context_window = 40960;
        max_tokens = 40960;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "scaleway";
    label = "Scaleway";
    base_url = "https://api.scaleway.ai/v1";
    env = [ "SCALEWAY_API_KEY" ];
    doc = "https://www.scaleway.com/en/docs/generative-apis/";
    models = [
      {
        Ai_catalog_spec.id = "qwen3.8-27b";
        label = "Qwen3.8 27B";
        context_window = 262144;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3-235b-a22b-instruct-2507";
        label = "Qwen3 235B A22B Instruct 2507";
        context_window = 260000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 256000;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 256000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gemma-4-26b-a4b-it";
        label = "Gemma 4 26B A4B IT";
        context_window = 256000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mistral-medium-3.5-128b";
        label = "Mistral Medium 3.5 128B";
        context_window = 256000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-397b-a17b";
        label = "Qwen3.5 397B A17B";
        context_window = 256000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.6-35b-a3b";
        label = "Qwen3.6 35B A3B";
        context_window = 128000;
        max_tokens = 16384;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-oss-120b";
        label = "GPT-OSS 120B";
        context_window = 128000;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3-coder-30b-a3b-instruct";
        label = "Qwen3-Coder 30B-A3B Instruct";
        context_window = 128000;
        max_tokens = 32768;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "pixtral-12b-2409";
        label = "Pixtral 12B 2409";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "mistral-small-3.2-24b-instruct-2506";
        label = "Mistral Small 3.2 24B Instruct (2506)";
        context_window = 128000;
        max_tokens = 32768;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "ovhcloud";
    label = "OVHcloud AI Endpoints";
    base_url = "https://oai.endpoints.kepler.ai.cloud.ovh.net/v1";
    env = [ "OVHCLOUD_API_KEY" ];
    doc = "https://www.ovhcloud.com/en/public-cloud/ai-endpoints/catalog//";
    models = [
      {
        Ai_catalog_spec.id = "qwen3.8-27b";
        label = "Qwen3.8-27B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.6-27b";
        label = "Qwen3.6-27B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-397b-a17b";
        label = "Qwen3.5-397B-A17B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.5-9b";
        label = "Qwen3.5-9B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-oss-20b";
        label = "gpt-oss-20b";
        context_window = 131072;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-oss-120b";
        label = "gpt-oss-120b";
        context_window = 131072;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3-coder-30b-a3b-instruct";
        label = "Qwen3-Coder-30B-A3B-Instruct";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "mistral-small-3.2-24b-instruct-2506";
        label = "Mistral-Small-3.2-24B-Instruct-2506";
        context_window = 131072;
        max_tokens = 131072;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "meta-llama-3_3-70b-instruct";
        label = "Meta-Llama-3_3-70B-Instruct";
        context_window = 131072;
        max_tokens = 131072;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "mistral-7b-instruct-v0.3";
        label = "Mistral-7B-Instruct-v0.3";
        context_window = 65536;
        max_tokens = 65536;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "mistral-nemo-instruct-2407";
        label = "Mistral-Nemo-Instruct-2407";
        context_window = 65536;
        max_tokens = 65536;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "vultr";
    label = "Vultr";
    base_url = "https://api.vultrinference.com/v1";
    env = [ "VULTR_API_KEY" ];
    doc = "https://api.vultrinference.com/";
    models = [
      {
        Ai_catalog_spec.id = "mimo-v2.6-pro-rl";
        label = "MiMo-V2.6-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "mimo-v2.6-flash-rl";
        label = "MiMo-V2.6-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4.1-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3-flash";
        label = "GLM-5.3-Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash-0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "laguna-s-2.1";
        label = "Laguna S 2.1";
        context_window = 1048576;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "minimax-m3";
        label = "MiniMax-M3";
        context_window = 524288;
        max_tokens = 512000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-flash-next";
        label = "Qwen3.8 Flash Next";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen3.8-27b";
        label = "Qwen3.8 27B";
        context_window = 262144;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nemotron-3-nano-omni-30b-a3b-reasoning";
        label = "Nemotron 3 Nano Omni 30B A3B Reasoning";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "crusoe";
    label = "Crusoe";
    base_url = "https://api.inference.crusoecloud.com/v1";
    env = [ "CRUSOE_API_KEY" ];
    doc = "https://docs.crusoecloud.com/managed-inference/overview";
    models = [
      {
        Ai_catalog_spec.id = "zai/GLM-5.2";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/Kimi-K2.6";
        label = "Kimi K2.6";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemma-4-31b-it";
        label = "Gemma 4 31B IT";
        context_window = 262144;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/NVIDIA-Nemotron-3-Super-120B-A12B";
        label = "Nemotron 3 Super 120B A12B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/NVIDIA-Nemotron-3-Nano-30B-A3B";
        label = "Nemotron 3 Nano 30B A3B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nvidia/Nemotron-3-Nano-Omni-Reasoning-30B-A3B";
        label = "Nemotron 3 Nano Omni 30B A3B Reasoning";
        context_window = 256000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai/GLM-5.1";
        label = "GLM-5.1";
        context_window = 200000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-oss-120b";
        label = "GPT OSS 120B";
        context_window = 131072;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3-235B-A22B-Instruct-2507";
        label = "Qwen3 235B-A22B Instruct 2507";
        context_window = 262144;
        max_tokens = 16384;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V3-0324";
        label = "DeepSeek V3 0324";
        context_window = 163840;
        max_tokens = 163840;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "meta-llama/Llama-3.3-70B-Instruct";
        label = "Llama-3.3-70B-Instruct";
        context_window = 128000;
        max_tokens = 4096;
        reasoning = false;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "digitalocean";
    label = "DigitalOcean";
    base_url = "https://inference.do-ai.run/v1";
    env = [ "DIGITALOCEAN_ACCESS_TOKEN" ];
    doc = "https://docs.digitalocean.com/products/gradient-ai-platform/details/models/";
    models = [
      {
        Ai_catalog_spec.id = "openai-gpt-6-1-sol";
        label = "OpenAI GPT-6.1 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-6-luna";
        label = "OpenAI GPT-6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-6-sol";
        label = "OpenAI GPT-6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-6-astra";
        label = "OpenAI GPT-6 Astra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-5.6-luna";
        label = "OpenAI GPT-5.6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-5.6-sol";
        label = "OpenAI GPT-5.6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-5.6-terra";
        label = "OpenAI GPT-5.6 Terra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai-gpt-5.4-pro";
        label = "OpenAI GPT-5.4 Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4.1-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3-flash";
        label = "GLM5.3 Flash";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-pro-0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM5.3";
        context_window = 1048576;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "gmicloud";
    label = "GMI Cloud";
    base_url = "https://api.gmi-serving.com/v1";
    env = [ "GMICLOUD_API_KEY" ];
    doc = "https://docs.gmicloud.ai/inference-engine/api-reference/llm-api-reference";
    models = [
      {
        Ai_catalog_spec.id = "openai/gpt-5.5";
        label = "GPT-5.5";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "MiniMaxAI/MiniMax-M3";
        label = "MiniMax-M3";
        context_window = 1048576;
        max_tokens = 512000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Pro";
        label = "DeepSeek V4 Pro";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.8-Flash";
        label = "Qwen3.8 Flash";
        context_window = 1048575;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-ai/DeepSeek-V4-Flash";
        label = "DeepSeek V4 Flash";
        context_window = 1048575;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "zai-org/GLM-5.2-FP8";
        label = "GLM-5.2";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-opus-4.8";
        label = "Claude Opus 4.8";
        context_window = 1000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.7-Max";
        label = "Qwen3.7 Max";
        context_window = 1000000;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-opus-4.7";
        label = "Claude Opus 4.7";
        context_window = 409600;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-opus-4.6";
        label = "Claude Opus 4.6";
        context_window = 409600;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-sonnet-4.6";
        label = "Claude Sonnet 4.6";
        context_window = 409600;
        max_tokens = 64000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.8-Max";
        label = "Qwen3.8 Max";
        context_window = 262144;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "hetzner";
    label = "Hetzner";
    base_url = "https://inference.hetzner.com/api/v1";
    env = [ "HETZNER_API_KEY" ];
    doc = "https://experiments.hetzner.com/docs/inference";
    models = [
      {
        Ai_catalog_spec.id = "Qwen3.8-27B";
        label = "Qwen3.8-27B";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "Qwen/Qwen3.6-35B-A3B-FP8";
        label = "Qwen3.6 35B A3B FP8";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "ollama-cloud";
    label = "Ollama Cloud";
    base_url = "https://ollama.com/v1";
    env = [ "OLLAMA_API_KEY" ];
    doc = "https://docs.ollama.com/cloud";
    models = [
      {
        Ai_catalog_spec.id = "deepseek-v4.1-flash";
        label = "DeepSeek V4.1 Flash";
        context_window = 1048576;
        max_tokens = 384000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-pro:0813";
        label = "DeepSeek V4 Pro 0813";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3";
        label = "GLM-5.3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash:0731";
        label = "DeepSeek V4 Flash 0731";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k3";
        label = "kimi-k3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-pro";
        label = "deepseek-v4-pro";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "deepseek-v4-flash";
        label = "deepseek-v4-flash";
        context_window = 1048576;
        max_tokens = 1048576;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "nemotron-3-nano:30b";
        label = "nemotron-3-nano:30b";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.3-flash";
        label = "GLM-5.3-Flash";
        context_window = 1000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "glm-5.2";
        label = "GLM-5.2";
        context_window = 976000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "minimax-m3";
        label = "minimax-m3";
        context_window = 512000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "kimi-k2.7-code";
        label = "kimi-k2.7-code";
        context_window = 262144;
        max_tokens = 262144;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "openrouter";
    label = "OpenRouter";
    base_url = "https://openrouter.ai/api/v1";
    env = [ "OPENROUTER_API_KEY" ];
    doc = "https://openrouter.ai/models";
    models = [
      {
        Ai_catalog_spec.id = "x-ai/grok-4.20";
        label = "Grok 4.20";
        context_window = 2000000;
        max_tokens = 1800000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openrouter/auto";
        label = "Auto Router";
        context_window = 2000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6.1-sol";
        label = "GPT-6.1 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6.1-sol-pro";
        label = "GPT-6.1 Sol Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xiaomi/mimo-v2.6-pro";
        label = "MiMo-V2.6-Pro";
        context_window = 1050000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xiaomi/mimo-v2.6-flash";
        label = "MiMo-V2.6-Flash";
        context_window = 1050000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-sol-pro";
        label = "GPT-6 Sol Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-luna";
        label = "GPT-6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-luna-pro";
        label = "GPT-6 Luna Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-sol";
        label = "GPT-6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "~openai/gpt-terra-latest";
        label = "GPT Terra Latest";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "~openai/gpt-luna-latest";
        label = "GPT Luna Latest";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "poe";
    label = "Poe";
    base_url = "https://api.poe.com/v1";
    env = [ "POE_API_KEY" ];
    doc = "https://creator.poe.com/docs/external-applications/openai-compatible-api";
    models = [
      {
        Ai_catalog_spec.id = "xai/grok-4.1-fast-reasoning";
        label = "Grok-4.1-Fast-Reasoning";
        context_window = 2000000;
        max_tokens = 30000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xai/grok-4-fast-reasoning";
        label = "Grok-4-Fast-Reasoning";
        context_window = 2000000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-2.5-flash";
        label = "Gemini-2.5-Flash";
        context_window = 1065535;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-2.5-pro";
        label = "Gemini-2.5-Pro";
        context_window = 1065535;
        max_tokens = 65535;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-opus-4.8";
        label = "Claude-Opus-4.8";
        context_window = 1048576;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-3.5-flash";
        label = "Gemini-3.5-Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "anthropic/claude-opus-4.7";
        label = "Claude-Opus-4.7";
        context_window = 1048576;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-3.1-pro";
        label = "Gemini-3.1-Pro";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-3.1-flash-lite";
        label = "Gemini-3.1-Flash-Lite";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-deep-research";
        label = "gemini-deep-research";
        context_window = 1048576;
        max_tokens = 8192;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-3-pro";
        label = "Gemini-3-Pro";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "google/gemini-3-flash";
        label = "Gemini-3-Flash";
        context_window = 1048576;
        max_tokens = 65536;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "requesty";
    label = "Requesty";
    base_url = "https://router.requesty.ai/v1";
    env = [ "REQUESTY_API_KEY" ];
    doc = "https://requesty.ai/solution/llm-routing/models";
    models = [
      {
        Ai_catalog_spec.id = "grok-4.2-beta";
        label = "grok-4.2-beta";
        context_window = 2000000;
        max_tokens = 2000000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6.1-sol@eu";
        label = "GPT-6.1 Sol (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6.1-sol";
        label = "GPT-6.1 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-luna";
        label = "GPT-6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-luna@eu";
        label = "GPT-6 Luna (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-sol@eu";
        label = "GPT-6 Sol (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-sol";
        label = "GPT-6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-6-astra";
        label = "GPT-6 Astra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-luna";
        label = "GPT-5.6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-sol@eu";
        label = "GPT-5.6 Sol (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-terra@eu";
        label = "GPT-5.6 Terra (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "gpt-5.6-luna@eu";
        label = "GPT-5.6 Luna (EU)";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "zenmux";
    label = "ZenMux";
    base_url = "https://zenmux.ai/api/v1";
    env = [ "ZENMUX_API_KEY" ];
    doc = "https://docs.zenmux.ai";
    models = [
      {
        Ai_catalog_spec.id = "openai/gpt-6-sol";
        label = "GPT-6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-astra";
        label = "GPT-6 Astra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.6-luna";
        label = "GPT-5.6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.6-terra";
        label = "GPT-5.6 Terra";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.6-sol";
        label = "GPT-5.6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.5-pro";
        label = "GPT-5.5 Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.5";
        label = "GPT-5.5";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.4";
        label = "GPT-5.4";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-5.4-pro";
        label = "GPT-5.4 Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "xiaomi/mimo-v2.6-pro";
        label = "MiMo-V2.6-Pro";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k3";
        label = "Kimi K3";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "moonshotai/kimi-k3-free";
        label = "Kimi K3 (Free)";
        context_window = 1048576;
        max_tokens = 131072;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "nano-gpt";
    label = "NanoGPT";
    base_url = "https://nano-gpt.com/api/v1";
    env = [ "NANO_GPT_API_KEY" ];
    doc = "https://docs.nano-gpt.com";
    models = [
      {
        Ai_catalog_spec.id = "pokee-isaac";
        label = "Pokee-Isaac 28B";
        context_window = 10000000;
        max_tokens = 60000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "x-ai/grok-4.20-multi-agent";
        label = "Grok 4.20 Multi-Agent";
        context_window = 2000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "x-ai/grok-4.20";
        label = "Grok 4.20";
        context_window = 2000000;
        max_tokens = 131072;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6.1-sol";
        label = "GPT 6.1 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6.1-sol-pro";
        label = "GPT 6.1 Sol Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-sol-pro";
        label = "GPT 6 Sol Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-luna";
        label = "GPT 6 Luna";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-luna-pro";
        label = "GPT 6 Luna Pro";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-6-sol";
        label = "GPT 6 Sol";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-terra-latest";
        label = "GPT Terra Latest";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-luna-latest";
        label = "GPT Luna Latest";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "openai/gpt-sol-latest";
        label = "GPT Sol Latest";
        context_window = 1050000;
        max_tokens = 128000;
        reasoning = true;
      };
    ];
  };
  {
    Ai_catalog_spec.id = "lmstudio";
    label = "LMStudio";
    base_url = "http://127.0.0.1:1234/v1";
    env = [ "LMSTUDIO_API_KEY" ];
    doc = "https://lmstudio.ai/models";
    models = [
      {
        Ai_catalog_spec.id = "openai/gpt-oss-20b";
        label = "GPT OSS 20B";
        context_window = 131072;
        max_tokens = 32768;
        reasoning = true;
      };
      {
        Ai_catalog_spec.id = "qwen/qwen3-30b-a3b-2507";
        label = "Qwen3 30B A3B 2507";
        context_window = 262144;
        max_tokens = 16384;
        reasoning = false;
      };
      {
        Ai_catalog_spec.id = "qwen/qwen3-coder-30b";
        label = "Qwen3 Coder 30B";
        context_window = 262144;
        max_tokens = 65536;
        reasoning = false;
      };
    ];
  };
]
