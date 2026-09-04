### 2. Index Templates Updated

Index templates ensure that all new indices automatically inherit the ILM policies.

#### Dev Logs Template

```json
PUT _index_template/dev-logs-template
{
  "index_patterns": ["cas-bciers-dev-logs-*"],
  "template": {
    "settings": {
      "index.lifecycle.name": "dev-logs-ilm",
      "number_of_shards": "2",
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
      "number_of_shards": "2",
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
      "number_of_shards": "2",
      "number_of_replicas": "1"
    }
  },
  "priority": 500
}
```

**Applies to indices matching:** `cas-bciers-prod-logs-*`
