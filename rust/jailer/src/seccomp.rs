use anyhow::Result;

/// Phase 0 permissive filter for bring-up. Tighten to an explicit allowlist in Phase 2.
pub fn apply_permissive_filter() -> Result<()> {
    Ok(())
}

#[allow(dead_code)]
const ALLOWED_SYSCALLS_PHASE2_TODO: &[&str] = &[
    "read",
    "write",
    "open",
    "close",
    "fstat",
    "mmap",
    "mprotect",
    "munmap",
    "ioctl",
    "epoll_wait",
    "epoll_ctl",
    "futex",
    "clock_gettime",
    "timerfd_create",
    "eventfd2",
    "sendmsg",
    "recvmsg",
    "exit_group",
];
