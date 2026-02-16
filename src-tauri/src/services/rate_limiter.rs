use std::time::Instant;

use crate::models::error::AppError;

const MAX_TOKENS: u32 = 50;
const REFILL_INTERVAL_SECS: u64 = 60;

pub struct RateLimiter {
    tokens: u32,
    last_refill: Instant,
}

impl Default for RateLimiter {
    fn default() -> Self {
        Self::new()
    }
}

impl RateLimiter {
    pub fn new() -> Self {
        Self {
            tokens: MAX_TOKENS,
            last_refill: Instant::now(),
        }
    }

    pub fn try_acquire(&mut self) -> Result<(), AppError> {
        self.refill();

        if self.tokens > 0 {
            self.tokens -= 1;
            Ok(())
        } else {
            Err(AppError::RateLimited)
        }
    }

    fn refill(&mut self) {
        let elapsed = self.last_refill.elapsed().as_secs();
        if elapsed >= REFILL_INTERVAL_SECS {
            let refill_count = (elapsed / REFILL_INTERVAL_SECS) as u32;
            self.tokens = (self.tokens + refill_count * MAX_TOKENS).min(MAX_TOKENS);
            self.last_refill = Instant::now();
        }
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn test_new_limiter_has_full_tokens() {
        let mut limiter = RateLimiter::new();
        for _ in 0..MAX_TOKENS {
            assert!(limiter.try_acquire().is_ok());
        }
    }

    #[test]
    fn test_limiter_rejects_when_exhausted() {
        let mut limiter = RateLimiter::new();
        for _ in 0..MAX_TOKENS {
            limiter.try_acquire().unwrap();
        }
        assert!(limiter.try_acquire().is_err());
    }
}
