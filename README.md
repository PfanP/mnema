# Mnema

![Build](https://github.com/PfanP/mnema/actions/workflows/ci.yml/badge.svg)
![License: MIT](https://img.shields.io/badge/License-MIT-blue.svg)
![Docker](https://img.shields.io/badge/docker-ready-blue?logo=docker)
![arXiv](https://img.shields.io/badge/arXiv-2605.11325-b31b1b.svg)

> Local long-term memory for any OpenAI-compatible client.

Mnema is a local proxy that sits between your AI client and any upstream LLM provider. It builds a structured model of your preferences, decisions, and working context from your conversations, then injects the relevant slice into every request — automatically, without any change to your client.

Point an OpenAI-compatible client at `http://localhost:5757/v1` and start working. The client does not need to know Mnema exists.

## Why Mnema

Every new session with an LLM starts from zero. You re-establish your stack, your voice, the decisions you made last week, and the approaches you have already ruled out. Most memory tools address this by storing transcripts and retrieving similar text, leaving the model to infer what matters and how to apply it.

Mnema takes a different approach:

- **Structured beliefs, not transcripts.** Every observation becomes a typed belief (Preference, Decision, Entity, Relation, Open Question) with a `why_it_matters` field the model can act on directly.
- **Rejected alternatives, indexed.** What you have ruled out is a first-class signal alongside what you have chosen. Ask about Mongoose and Mnema surfaces your decision to use the raw MongoDB driver.
- **Alias-weighted retrieval.** Returns the belief that matches what you are actually asking about, not everything in the same semantic neighborhood.
- **Scoped context.** A universal / domain / project hierarchy keeps engineering preferences out of creative sessions and one project's stack out of another's.
- **Mid-session corrections.** Recent turns are always injected in full so the model sees corrections immediately; the extraction worker reconciles older beliefs asynchronously.

## Installation

**Linux / macOS**

```bash
curl -fsSL https://raw.githubusercontent.com/PfanP/mnema/main/scripts/install.sh | bash
```

**Windows (PowerShell)**

```powershell
irm https://raw.githubusercontent.com/PfanP/mnema/main/scripts/install.ps1 | iex
```

The installer prints your API token on first start and saves it to `~/.mnema/token`. Full setup instructions live in [docs/quickstart.md](docs/quickstart.md).

## Getting Started

1. **Onboarding.** Open [http://localhost:5757/onboarding](http://localhost:5757/onboarding) to connect a provider, pick a default model, and seed your world model.
2. **Point your client.** Configure it with base URL `http://localhost:5757/v1` and the bearer token from `~/.mnema/token`.
3. **Inspect.** Open [http://localhost:5757/beliefs](http://localhost:5757/beliefs) to view, pin, edit, or remove beliefs.

Per-client setup notes (chat UIs, IDEs, manual integrations) are in [docs/clients.md](docs/clients.md).

## How It Works

On every request, Mnema:

1. **Assembles context.** Selects a token-budgeted slice of the world model relevant to the current turn.
2. **Injects.** Adds the slice to the system prompt alongside a structured sidecar block the model writes back. The sidecar is stripped before the response returns to your client.
3. **Forwards the request.** Calls the resolved provider in streaming or non-streaming mode and returns a standard OpenAI-format response.
4. **Extracts asynchronously.** A background worker analyzes the exchange and updates the belief store after the response is delivered. Extraction never blocks the request path.

## World Model

Beliefs are typed (`Preference`, `Decision`, `Entity`, `Relation`, `OpenQuestion`) and scoped to one of three levels:

| Scope     | Applies to                                     | Example                                     |
| --------- | ---------------------------------------------- | ------------------------------------------- |
| Universal | Every session                                  | Communication style, engagement preferences |
| Domain    | A discipline (`domain:code`, `domain:writing`) | Stack choices, tool preferences             |
| Project   | A named project                                | Repo conventions, database choice           |

Sub-domains narrow further (`domain:code/typescript`).

Scope is detected automatically from the first message. Override or pause with chat commands:

```
!scope domain:writing
!scope domain:code/typescript
!extract off          # stop recording this session
!extract on           # resume
!extract global off   # pause everywhere
```

See [docs/beliefs.md](docs/beliefs.md) for the full reference.

## Supported Models

Belief extraction depends on reliable structured output. Heavily quantized or smaller models do not meet the consistency the extraction worker requires.

| Family          | Minimum                        | Status    |
| --------------- | ------------------------------ | --------- |
| Claude          | 4.5 and above                  | Community |
| GPT             | GPT-4o-mini and above          | Community |
| OpenAI o-series | o3, o4-mini and above          | Community |
| Bedrock Claude  | Anthropic Claude 4.5 and above | Verified  |
| Bedrock Nova    | Amazon Nova Pro                | Community |

Any OpenAI-compatible endpoint serving one of these models is supported, including Bedrock gateways and LiteLLM proxies.

## Token Efficiency

- **Selective retrieval** keeps the injected context compact.
- **Continuous compaction** prevents the belief store from growing unbounded.
- **Prompt caching** on the static and belief tiers means context injection is paid for once per session.

See [docs/prompt-caching.md](docs/prompt-caching.md).

## Security and Privacy

- **Local-only.** All processing happens on your machine. Context never leaves `localhost`.
- **Encrypted at rest.** Belief content is encrypted on disk. See [docs/security.md](docs/security.md).
- **Inspectable.** Every belief is visible and editable at `/beliefs`. Pin what should always surface; correct what is wrong.
- **Portable.** Export the world model as a passphrase-encrypted archive and restore it on any machine.
- **Pausable.** Stop extraction globally from Settings or per-session via `!extract off`.

## Performance Notes

Mnema is conservative by design — it prefers surfacing nothing over surfacing the wrong belief. If a belief is not appearing when expected, pinning it is the most direct fix. Retrieval quality improves over time as the system learns the ways you refer to things. See [docs/retrieval.md](docs/retrieval.md).

Cold-start sessions are usable from day one and improve significantly over the first dozen sessions as the world model fills out. Importing an existing skills file or completing onboarding accelerates the ramp.

## Evaluation

The retrieval results in the accompanying paper are reproducible from this repository. See [docs/eval.md](docs/eval.md). The BM25 evaluation requires only Docker.

## Roadmap

Multi-user support and belief sharing are not yet implemented. See [docs/roadmap.md](docs/roadmap.md) for what is planned.

## Contributing

Contributions are welcome. See [docs/contributing.md](docs/contributing.md).

## License

[MIT](LICENSE)
