use std::collections::HashMap;

pub struct ResponseCache {
    store: HashMap<String, serde_json::Value>,
}

impl Default for ResponseCache {
    fn default() -> Self {
        Self::new()
    }
}

impl ResponseCache {
    pub fn new() -> Self {
        Self {
            store: HashMap::new(),
        }
    }

    pub fn get(&self, key: &str) -> Option<&serde_json::Value> {
        self.store.get(key)
    }

    pub fn set(&mut self, key: String, value: serde_json::Value) {
        self.store.insert(key, value);
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_cache_miss_returns_none() {
        let cache = ResponseCache::new();
        assert!(cache.get("missing").is_none());
    }

    #[test]
    fn test_cache_hit_returns_value() {
        let mut cache = ResponseCache::new();
        let val = serde_json::json!({"data": [1, 2, 3]});
        cache.set("albums".to_string(), val.clone());
        assert_eq!(cache.get("albums").unwrap(), &val);
    }
}
