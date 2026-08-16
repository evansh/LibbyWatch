# Legal applicant and API Agreement owner

**Issue**: #2 — Identify the legal applicant and API Agreement owner  
**Priority**: P0  
**Milestone**: 0 — Feasibility & Access  
**Status**: In progress

## Purpose

Document the legal entity and authorized signatory who will:
1. Accept the OverDrive API License Agreement
2. Own the client credentials and integration access
3. Be contractually responsible for compliance, audit, and liability

## Requirements from OverDrive

- A legal entity (company, LLC, nonprofit, or individual) capable of entering a binding contract
- An authorized signatory with authority to accept the API Agreement terms
- Contact information for legal notices and compliance communications
- Ability to maintain insurance/indemnification as required by the Agreement

## Candidate options

| Option | Entity type | Pros | Cons | Status |
|--------|-------------|------|------|--------|
| Individual (sole proprietor) | Natural person | Fastest to establish; full control | Personal liability; no liability shield | Under review |
| New LLC (US) | Limited liability company | Liability protection; professional; standard for API agreements | Formation time (days-weeks); cost; ongoing compliance | Recommended |
| Existing entity | Any registered entity | Immediate if available | Must confirm scope alignment and authority | N/A |
| Nonprofit | 501(c)(3) or equivalent | Mission alignment; potential grant eligibility | Formation complexity; restrictions on commercial activity | Not applicable |

## Recommended path: New single-member LLC

**Rationale**:
- Standard structure for API vendor agreements
- Liability protection for personal assets
- Clear ownership and authority
- Can be formed in 1-3 business days in most US states
- Cost: ~$50-500 filing fee + registered agent (~$50-150/year)

### Formation checklist

- [ ] Choose state of formation (recommend: Delaware or home state)
- [ ] Reserve/check entity name (e.g., "LibbyWatch LLC" or similar)
- [ ] File Articles of Organization / Certificate of Formation
- [ ] Obtain EIN from IRS (free, online, immediate)
- [ ] Draft Operating Agreement (single-member)
- [ ] Open business bank account
- [ ] Designate registered agent
- [ ] Document authorized signatory (sole member = full authority)

### Authorized signatory

Once formed, the sole member/manager is the authorized signatory for the API Agreement.

**Name**: _________________________  
**Title**: Sole Member / Manager  
**Entity**: _________________________ LLC  
**Date**: _________________________

## API Agreement acceptance record

| Field | Value |
|-------|-------|
| Legal entity name | |
| Entity type / jurisdiction | |
| EIN / tax ID | |
| Authorized signatory name | |
| Authorized signatory title | |
| Signatory email | |
| Signatory phone | |
| Registered agent name | |
| Registered agent address | |
| Principal business address | |
| Date of API Agreement acceptance | |
| OverDrive developer account email | |
| Client credential owner (backend) | |

## Next steps

1. Complete entity formation
2. Record all details above
3. Use entity information for OverDrive developer portal registration
4. Proceed to Issue #6: Submit access request

## Related documents

- [OVERDRIVE-ACCESS.md](OVERDRIVE-ACCESS.md) — Access request plan
- [OVERDRIVE-COMPLIANCE.md](OVERDRIVE-COMPLIANCE.md) — Compliance matrix
- [GitHub Issue #2](https://github.com/evansh/LibbyWatch/issues/2)

---

*This document is part of the LibbyWatch feasibility evidence package. It does not constitute legal advice. Consult counsel before forming an entity or accepting the API Agreement.*