# 05: Safety Layer - The Defensive Shield

## 1. Concept Overview

The **Safety Layer** operates at the exact absolute boundaries of the system. It inspects every byte of text flowing *into* the LLM from the user, and every byte flowing *out of* the LLM back to the user or into the Tool Layer.

**What problem it solves:**
LLMs are highly susceptible to adversarial attacks. A malicious user might craft a "Prompt Injection" asking the LLM to ignore all previous instructions and dump the enterprise's private API keys. Furthermore, LLMs can inadvertently hallucinate toxic content, leak Personally Identifiable Information (PII), or generate outputs that severely violate corporate brand policies.

**Why it exists in production:**
To prevent catastrophic PR disasters, regulatory fines (GDPR/HIPAA violations), and internal data exfiltration.

---

## 2. Responsibilities of the Layer

1. **Input Filtering (Jailbreak Protection):** Detecting adversarial prompt injections, malicious intent, or prohibited topics (e.g., preventing a banking bot from giving medical advice).
2. **Input Sanitization (PII Protection):** Masking or redacting sensitive data like Social Security Numbers or credit cards *before* they are sent to third-party LLM APIs.
3. **Output Validation (Moderation):** Ensuring the LLM's response does not contain hate speech, competitor mentions, or hallucinated malicious code.
4. **Policy Enforcement:** Establishing strict rules (Guardrails) that govern the bounds of the AI's allowed behavior.

---

## 3. Workflow Placement

The Safety Layer wraps the entire architecture in a protective shell. It is the first thing hit by user input and the last thing hitting user output.

```text
[ User Client ]
      │ (Input)
      ▼
==========================
    SAFETY LAYER (In)
==========================
      │ (Cleaned Input)
      ▼
[ Internal Layers: Intent, Orchestration, Reason ]
      │ (Raw Output)
      ▼
==========================
    SAFETY LAYER (Out)
==========================
      │ (Validated Output)
      ▼
[ User Client ]
```

---

## 4. Internal Architecture

The Architecture of a Guardrail system usually consists of a series of fast, deterministic, or highly constrained validation models operating sequentially or in parallel:

1. **Regex/Heuristics Scanner:** Extremely fast checks for standard PII (email, phone, SSN) and banned word lists.
2. **Small Classification SLMs:** Fast, local ML models specifically trained to detect Prompt Injections or Toxic Content (e.g., Llama-Guard, RoBERTa-based sentiment classifiers).
3. **The Proxy Masker:** A component that replaces PII with tokens (e.g., replacing `John Doe` with `[PERSON_1]`) on the way in, and de-tokenizes them on the way out, allowing the LLM to process the request without ever seeing the raw data.
4. **The Policy Firewall:** An execution block. If a safety check fails, it immediately terminates the downstream request and returns a canned, safe response to the user.

---

## 5. Implementation Approaches

### Simple Startup Version
Using the native Moderation API provided by OpenAI (`/v1/moderations`) before executing the generation call, alongside a simple blocklist for competitor names. 

### Scalable Production Version
Deploying open-source Guardrail frameworks (like NeMo Guardrails or Guardrails AI). Implementing dedicated local models for PII redaction (e.g., Microsoft Presidio) to ensure sensitive data never leaves the VPC.

### Enterprise Version
A dedicated, isolated microservice operating at the API Gateway level. It uses sophisticated ensemble models to detect subtle advanced jailbreaks (like ASCII art injections or base64 encoded malicious prompts). Fully compliant with SOC2/HIPAA, featuring detailed audit logging of every blocked prompt for security analysts to review.

---

## 6. Example Implementation

Here is a pseudo-code implementation showing an Input Safety Pipeline utilizing a Guardrails architecture:

```python
class SafetyLayer:
    def __init__(self, pii_scanner, injection_detector, policy_enforcer):
        self.pii = pii_scanner
        self.injection = injection_detector
        self.policy = policy_enforcer

    def screen_input(self, text: str) -> dict:
        # 1. PII Redaction
        redacted_text, entities = self.pii.mask(text)
        
        # 2. Jailbreak Detection 
        # (Using a fast, local binary classification model)
        if self.injection.detect(redacted_text) > 0.85:
            raise SecurityException("Prompt Injection Detected")
            
        # 3. Policy Enforcement (e.g. topic modeling)
        if not self.policy.is_allowed_topic(redacted_text):
            raise SecurityException("Topic violation: Out of bounds")
            
        # Return cleaned payload to pass to Intent Layer
        return {"clean_text": redacted_text, "entity_map": entities}

    def screen_output(self, generated_text: str, entity_map: dict) -> str:
        # 1. Hallucination/Toxicity check
        if self.policy.is_toxic(generated_text):
            return "I apologize, but I cannot generate a response."
            
        # 2. De-masking PII
        final_text = self.pii.unmask(generated_text, entity_map)
        return final_text
```

---

## 7. Technology Options

* **PII Redaction:** Microsoft Presidio, AWS Comprehend Medical, Google Cloud DLP.
* **Malicious Intent / Injection Detection:** Llama-Guard, Lakera Guard, ProtectAI, Rebuff.
* **Guardrail Frameworks:** Nvidia NeMo Guardrails, Guardrails AI, Outlines.

**When to use each:** Use Presidio for on-premise PII redaction. Use specialized enterprise firewall products (Lakera/ProtectAI) when deploying customer-facing chatbots that are highly likely to be targeted by red teams and trolls.

---

## 8. Scaling Considerations

* **At 1k Users:** Calling a 3rd party Moderation API synchronously is fine.
* **At 10k Users:** Safety checks must be heavily parallelized. The Jailbreak check, PII check, and Topic check must execute simultaneously. 
* **At 100k Users:** Latency added by the Safety Layer becomes the biggest issue. Moving from heavy API-based moderation to hyper-optimized Rust-based local inference nodes running ONNX models is necessary to keep the safety tax below ~50ms per request.

---

## 9. Failure Handling

* **False Positives:** The biggest risk in the Safety Layer is being overly zealous and blocking legitimate requests (e.g., blocking medical terms in a biology tutoring app). The system must allow users to flag false positives, which are fed back to an observability dashboard for manual threshold tuning.
* **Fail Open vs. Fail Closed:** If the Safety microservice crashes, the system must "Fail Closed". An AI system should *never* process prompts if its protective shield is offline, as this opens the architecture to immediate exploitation.

---

## 10. Cost Optimization

1. **Layered Defense (Fast-to-Slow):** Run $0 Regex filters first. If they pass, run $0.0001 local SLM classifiers. Only if those are ambiguous do you run a prompt injection check through an expensive LLM API.
2. **Client-Side vs Server-Side:** Push generic profanity or vulgarity checks to the client UI. If the user types heavy profanity, the frontend can reject it instantly without wasting any backend compute or API costs.
