use anyhow::{anyhow, Result};
use seccomp::{Action, Compare, Context, Op, Rule};

/// Phase 0 permissive filter for bring-up. Tighten to an explicit allowlist in Phase 2.
pub fn apply_permissive_filter() -> Result<()> {
    Ok(())
}

pub fn apply_allowlist_filter() -> Result<()> {
    let mut ctx = Context::default(Action::Errno(libc::EPERM))
        .map_err(|e| anyhow!("seccomp context init failed: {}", e))?;

    for syscall in ALLOWED_SYSCALLS {
        let cmp = Compare::arg(0)
            .using(Op::Ge)
            .with(0)
            .build()
            .ok_or_else(|| anyhow!("failed to build seccomp comparator"))?;

        let rule = Rule::new(*syscall as usize, cmp, Action::Allow);
        ctx.add_rule(rule)
            .map_err(|e| anyhow!("failed to add seccomp rule for syscall {}: {}", syscall, e))?;
    }

    ctx.load()
        .map_err(|e| anyhow!("failed to load seccomp filter into kernel: {}", e))?;

    Ok(())
}

#[allow(dead_code)]
const ALLOWED_SYSCALLS: &[libc::c_long] = &[
    libc::SYS_read,
    libc::SYS_write,
    libc::SYS_open,
    libc::SYS_openat,
    libc::SYS_close,
    libc::SYS_stat,
    libc::SYS_fstat,
    libc::SYS_lseek,
    libc::SYS_mmap,
    libc::SYS_mprotect,
    libc::SYS_munmap,
    libc::SYS_brk,
    libc::SYS_rt_sigaction,
    libc::SYS_rt_sigprocmask,
    libc::SYS_ioctl,
    libc::SYS_pread64,
    libc::SYS_pwrite64,
    libc::SYS_readv,
    libc::SYS_writev,
    libc::SYS_access,
    libc::SYS_pipe,
    libc::SYS_pipe2,
    libc::SYS_select,
    libc::SYS_ppoll,
    libc::SYS_pselect6,
    libc::SYS_sched_yield,
    libc::SYS_getpid,
    libc::SYS_gettid,
    libc::SYS_futex,
    libc::SYS_nanosleep,
    libc::SYS_clock_gettime,
    libc::SYS_epoll_create1,
    libc::SYS_epoll_ctl,
    libc::SYS_epoll_wait,
    libc::SYS_eventfd2,
    libc::SYS_timerfd_create,
    libc::SYS_timerfd_settime,
    libc::SYS_timerfd_gettime,
    libc::SYS_socket,
    libc::SYS_bind,
    libc::SYS_listen,
    libc::SYS_accept4,
    libc::SYS_connect,
    libc::SYS_sendto,
    libc::SYS_recvfrom,
    libc::SYS_sendmsg,
    libc::SYS_recvmsg,
    libc::SYS_setsockopt,
    libc::SYS_getsockopt,
    libc::SYS_clone,
    libc::SYS_execve,
    libc::SYS_exit,
    libc::SYS_exit_group,
    libc::SYS_prlimit64,
    libc::SYS_uname,
    libc::SYS_getrandom,
    libc::SYS_madvise,
    libc::SYS_dup,
    libc::SYS_dup2,
    libc::SYS_dup3,
    libc::SYS_getcwd,
    libc::SYS_chdir,
    libc::SYS_rename,
    libc::SYS_renameat,
    libc::SYS_renameat2,
    libc::SYS_mkdir,
    libc::SYS_rmdir,
    libc::SYS_unlink,
    libc::SYS_unlinkat,
    libc::SYS_ftruncate,
    libc::SYS_fallocate,
    libc::SYS_fsync,
    libc::SYS_fdatasync,
    libc::SYS_getuid,
    libc::SYS_geteuid,
    libc::SYS_getgid,
    libc::SYS_getegid,
    libc::SYS_setuid,
    libc::SYS_setgid,
    libc::SYS_arch_prctl,
];

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
