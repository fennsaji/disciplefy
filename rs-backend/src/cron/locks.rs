//! Cross-instance leases for scheduled jobs.
//!
//! [`CronGuard`] stops a job overlapping itself inside one process. It cannot
//! see another process, so with two containers every job fires twice: two daily
//! posts in a fellowship, two Telegram messages, a pre-warm batch submitted and
//! billed twice.
//!
//! A lease in the database closes that. A job takes one before it starts and
//! releases it when it finishes; another instance that finds a live lease skips
//! its turn, which is the same thing the in-process guard does and the right
//! answer for a job that runs on a schedule anyway.
//!
//! Leases expire rather than being held forever, so a crashed or killed
//! instance frees its job by itself. Pick a duration comfortably longer than
//! the job's real runtime: expiring early is what lets a double-run happen.

use sqlx::PgPool;
use std::time::Duration;

use crate::error::AppError;

/// Held while a job runs. Call [`CronLease::release`] when finished; if the
/// process dies first, the lease expires on its own.
pub struct CronLease {
    pool: PgPool,
    name: String,
    holder: String,
}

/// Identifies this instance in the lease row and in the logs.
fn holder_id() -> String {
    std::env::var("FLY_MACHINE_ID")
        .or_else(|_| std::env::var("HOSTNAME"))
        .unwrap_or_else(|_| format!("pid-{}", std::process::id()))
}

impl CronLease {
    /// Takes the lease for `name`, or returns `None` if another instance holds
    /// a live one.
    ///
    /// A database failure returns `None`: skipping a scheduled run is the safe
    /// side of that error, since the job will come round again, while running
    /// without a lease is how the duplicate work this exists to prevent gets
    /// through.
    pub async fn try_acquire(pool: &PgPool, name: &str, ttl: Duration) -> Option<Self> {
        let holder = holder_id();
        let ttl_seconds = ttl.as_secs() as i64;

        let acquired = sqlx::query_scalar::<_, String>(
            r#"
            INSERT INTO cron_locks (name, locked_until, holder, acquired_at)
            VALUES ($1, now() + make_interval(secs => $2::double precision), $3, now())
            ON CONFLICT (name) DO UPDATE
               SET locked_until = EXCLUDED.locked_until,
                   holder       = EXCLUDED.holder,
                   acquired_at  = now()
             WHERE cron_locks.locked_until < now()
            RETURNING name
            "#,
        )
        .bind(name)
        .bind(ttl_seconds as f64)
        .bind(&holder)
        .fetch_optional(pool)
        .await;

        match acquired {
            Ok(Some(_)) => Some(CronLease {
                pool: pool.clone(),
                name: name.to_string(),
                holder,
            }),
            Ok(None) => {
                tracing::info!(job = name, "Another instance holds the lease — skipping");
                None
            }
            Err(e) => {
                tracing::error!(job = name, error = %e, "Could not take the lease — skipping this run");
                None
            }
        }
    }

    /// Frees the lease so the next run can start without waiting for expiry.
    ///
    /// Scoped to this holder, so a run that overran its lease cannot release the
    /// lease another instance has since taken.
    pub async fn release(self) -> Result<(), AppError> {
        sqlx::query("UPDATE cron_locks SET locked_until = now() WHERE name = $1 AND holder = $2")
            .bind(&self.name)
            .bind(&self.holder)
            .execute(&self.pool)
            .await
            .map_err(|e| {
                AppError::Internal(format!("Could not release the {} lease: {e}", self.name))
            })?;

        Ok(())
    }
}

#[cfg(test)]
mod tests {
    use super::*;

    /// These need a database, so they run against the local Supabase instance.
    fn test_pool() -> Option<PgPool> {
        let url = std::env::var("TEST_DATABASE_URL").ok()?;
        sqlx::postgres::PgPoolOptions::new()
            .max_connections(2)
            .connect_lazy(&url)
            .ok()
    }

    #[tokio::test]
    async fn a_second_holder_is_refused_while_the_lease_is_live() {
        let Some(pool) = test_pool() else { return };
        let job = "test_lease_exclusive";
        sqlx::query("DELETE FROM cron_locks WHERE name = $1")
            .bind(job)
            .execute(&pool)
            .await
            .unwrap();

        let first = CronLease::try_acquire(&pool, job, Duration::from_secs(60)).await;
        assert!(first.is_some(), "the first caller should take the lease");

        let second = CronLease::try_acquire(&pool, job, Duration::from_secs(60)).await;
        assert!(second.is_none(), "a second caller must be refused");

        first.unwrap().release().await.unwrap();

        let third = CronLease::try_acquire(&pool, job, Duration::from_secs(60)).await;
        assert!(third.is_some(), "the lease should be free once released");
        third.unwrap().release().await.unwrap();
    }

    #[tokio::test]
    async fn an_expired_lease_is_taken_over() {
        let Some(pool) = test_pool() else { return };
        let job = "test_lease_expiry";
        sqlx::query("DELETE FROM cron_locks WHERE name = $1")
            .bind(job)
            .execute(&pool)
            .await
            .unwrap();

        // A crashed instance leaves its lease behind; it must not block forever.
        let abandoned = CronLease::try_acquire(&pool, job, Duration::from_secs(0)).await;
        assert!(abandoned.is_some());
        std::mem::forget(abandoned);

        let next = CronLease::try_acquire(&pool, job, Duration::from_secs(60)).await;
        assert!(next.is_some(), "an expired lease should be available again");
        next.unwrap().release().await.unwrap();
    }
}
