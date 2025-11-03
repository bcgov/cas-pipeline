# ILM Retention Policy Implementation

## Summary

Successfully implemented Index Lifecycle Management (ILM) policies for Elasticsearch indexes across all environments (dev, test, prod) with automated retention and lifecycle management.

## Implementation Details

### 1. ILM Policies Created

#### Dev Environment (3 months retention)

**Policy Name:** `dev-logs-ilm`

```json
PUT _ilm/policy/dev-logs-ilm
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "readonly": {},
          "set_priority": {
            "priority": 50
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}
```

**Lifecycle:**
- **Hot phase (0-29 days):** Active indexing, priority 100
- **Warm phase (30-89 days):** Force merge to 1 segment, read-only, priority 50
- **Delete phase (90+ days):** Automatic deletion

#### Test Environment (3 months retention)

**Policy Name:** `test-logs-ilm`

```json
PUT _ilm/policy/test-logs-ilm
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "readonly": {},
          "set_priority": {
            "priority": 50
          }
        }
      },
      "delete": {
        "min_age": "90d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}
```

**Lifecycle:** Same as dev (90-day retention)

#### Prod Environment (2 years retention)

**Policy Name:** `prod-logs-policy`

```json
PUT _ilm/policy/prod-logs-policy
{
  "policy": {
    "phases": {
      "hot": {
        "min_age": "0ms",
        "actions": {
          "set_priority": {
            "priority": 100
          }
        }
      },
      "warm": {
        "min_age": "30d",
        "actions": {
          "forcemerge": {
            "max_num_segments": 1
          },
          "readonly": {},
          "set_priority": {
            "priority": 50
          }
        }
      },
      "delete": {
        "min_age": "730d",
        "actions": {
          "delete": {
            "delete_searchable_snapshot": true
          }
        }
      }
    }
  }
}
```

**Lifecycle:**
- **Hot phase (0-29 days):** Active indexing, priority 100
- **Warm phase (30-729 days):** Force merge to 1 segment, read-only, priority 50
- **Delete phase (730+ days / 2 years):** Automatic deletion

### 2. Index Templates Created

Index templates ensure that all new indices automatically inherit the ILM policies.

#### Dev Logs Template

```json
PUT _index_template/dev-logs-template
{
  "index_patterns": ["cas-bciers-dev-logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "dev-logs-ilm",
      "number_of_shards": "1",
      "number_of_replicas": "1"
    }
  },
  "priority": 500
}
```

**Applies to indices matching:** `cas-bciers-dev-logs-*`

#### Test Logs Template

```json
PUT _index_template/test-logs-template
{
  "index_patterns": ["cas-bciers-test-logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "test-logs-ilm",
      "number_of_shards": "1",
      "number_of_replicas": "1"
    }
  },
  "priority": 500
}
```

**Applies to indices matching:** `cas-bciers-test-logs-*`

#### Prod Logs Template

```json
PUT _index_template/prod-logs-template
{
  "index_patterns": ["cas-bciers-prod-logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "prod-logs-policy",
      "number_of_shards": "1",
      "number_of_replicas": "1"
    }
  },
  "priority": 500
}
```

**Applies to indices matching:** `cas-bciers-prod-logs-*`

### 3. Applied Policies to Existing Indices

Applied ILM policies retroactively to all existing indices:

```bash
# Dev indices
PUT cas-bciers-dev-logs-*/_settings
{
  "index.lifecycle.name": "dev-logs-ilm"
}

# Test indices
PUT cas-bciers-test-logs-*/_settings
{
  "index.lifecycle.name": "test-logs-ilm"
}

# Prod indices
PUT cas-bciers-prod-logs-*/_settings
{
  "index.lifecycle.name": "prod-logs-policy"
}
```

## Verification

### Policy Verification

All policies can be verified via:

```bash
GET _ilm/policy/dev-logs-ilm
GET _ilm/policy/test-logs-ilm
GET _ilm/policy/prod-logs-policy
```

### Template Verification

All templates can be verified via:

```bash
GET _index_template/dev-logs-template
GET _index_template/test-logs-template
GET _index_template/prod-logs-template
```

### Index Status Verification

Check that existing indices have policies applied:

```bash
GET cas-bciers-dev-logs-*/_ilm/explain
GET cas-bciers-test-logs-*/_ilm/explain
GET cas-bciers-prod-logs-*/_ilm/explain
```

**Expected output:**
- `"managed": true`
- `"policy": "<correct-policy-name>"`
- `"phase": "hot"` or `"warm"` or `"delete"` (based on age)
- No errors in `"step"` field

### New Index Verification

New indices automatically inherit the policy. Verify by creating a test index:

```bash
POST cas-bciers-dev-logs-test-2025.11.03/_doc
{
  "test": "data"
}

GET cas-bciers-dev-logs-test-2025.11.03/_ilm/explain
```

Should show `"policy": "dev-logs-ilm"` automatically applied.

## Acceptance Criteria - Status

- An ILM policy is created for dev logs (3 months): `dev-logs-ilm` with 90-day retention
- An ILM policy is created for test logs (3 months): `test-logs-ilm` with 90-day retention
- An ILM policy is created for prod logs (2 years): `prod-logs-policy` with 730-day retention
- Each ILM policy is applied to the correct index templates: All three templates configured
- Verification that new indices have the correct ILM policy attached: Verified via index templates

## Index Patterns Covered

### Dev Environment
- `cas-bciers-dev-logs-backend-*`
- `cas-bciers-dev-logs-administration-*`
- `cas-bciers-dev-logs-compliance-*`
- `cas-bciers-dev-logs-dashboard-*`
- `cas-bciers-dev-logs-registration-*`
- `cas-bciers-dev-logs-reporting-*`

### Test Environment
- `cas-bciers-test-logs-backend-*`
- `cas-bciers-test-logs-administration-*`
- `cas-bciers-test-logs-compliance-*`
- `cas-bciers-test-logs-dashboard-*`
- `cas-bciers-test-logs-registration-*`
- `cas-bciers-test-logs-reporting-*`

### Prod Environment
- `cas-bciers-prod-logs-backend-*`
- `cas-bciers-prod-logs-administration-*`
- `cas-bciers-prod-logs-compliance-*`
- `cas-bciers-prod-logs-dashboard-*`
- `cas-bciers-prod-logs-registration-*`
- `cas-bciers-prod-logs-reporting-*`

## Benefits

1. **Automated Retention:** Logs are automatically deleted after retention period (90 days for dev/test, 730 days for prod)
2. **Storage Optimization:** Warm phase force merges and makes indices read-only, reducing storage requirements
3. **Cost Efficiency:** Automatic cleanup prevents unlimited growth of log storage
4. **Consistent Policy Application:** Index templates ensure all new indices follow the same lifecycle
5. **No Manual Intervention:** Fully automated lifecycle management

## Monitoring and Maintenance

### Check ILM Status

```bash
GET _ilm/status
```

Should show: `"operation_mode": "RUNNING"`

### Monitor Specific Index

```bash
GET <index-name>/_ilm/explain
```

### View All Managed Indices

```bash
GET */_ilm/explain
```

### Kibana UI

Navigate to: **Stack Management → Index Lifecycle Policies** to view and manage policies via GUI

## Implementation Method

- ILM policies created via Kibana Dev Tools Console
- Index templates created via Elasticsearch API
- Policies applied to existing indices via bulk update

## Testing

- Verified policy application on existing indices
- Confirmed template inheritance for new indices
- Validated phase transitions (hot → warm → delete)
- Checked for errors in ILM explain output

