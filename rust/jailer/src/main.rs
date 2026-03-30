#[cfg(target_os = "linux")]
mod cgroups;
#[cfg(target_os = "linux")]
mod seccomp;

#[cfg(target_os = "linux")]
use anyhow::{Context, Result};
#[cfg(target_os = "linux")]
use clap::Parser;
#[cfg(target_os = "linux")]
use nix::unistd::{setgid, setuid, Gid, Uid};
#[cfg(target_os = "linux")]
use std::os::unix::process::CommandExt;
#[cfg(target_os = "linux")]
use std::path::PathBuf;
#[cfg(target_os = "linux")]
use std::process::Command;

#[cfg(target_os = "linux")]
#[derive(Parser, Debug)]
#[command(name = "infinity-jailer")]
struct Args {
    #[arg(long, default_value = "/usr/local/bin/firecracker")]
    firecracker: PathBuf,

    #[arg(long)]
    api_sock: PathBuf,

    #[arg(long)]
    config_file: PathBuf,

    #[arg(long)]
    cgroup_name: String,

    #[arg(long, default_value = "268435456")]
    memory_limit_bytes: u64,

    #[arg(long, default_value = "1024")]
    cpu_shares: u64,

    #[arg(long, default_value = "1000")]
    uid: u32,

    #[arg(long, default_value = "1000")]
    gid: u32,
}

#[cfg(target_os = "linux")]
fn main() -> Result<()> {
    let args = Args::parse();

    cgroups::setup(&args.cgroup_name, args.memory_limit_bytes, args.cpu_shares)
        .context("failed to configure cgroups")?;

    cgroups::enter(&args.cgroup_name).context("failed to enter cgroup")?;

    seccomp::apply_permissive_filter().context("failed to apply seccomp filter")?;

    setgid(Gid::from_raw(args.gid)).context("setgid failed")?;
    setuid(Uid::from_raw(args.uid)).context("setuid failed")?;

    let err = Command::new(&args.firecracker)
        .arg("--api-sock")
        .arg(&args.api_sock)
        .arg("--config-file")
        .arg(&args.config_file)
        .exec();

    Err(anyhow::anyhow!("exec failed: {}", err))
}

#[cfg(not(target_os = "linux"))]
fn main() {
    eprintln!("infinity-jailer is only supported on Linux hosts");
    std::process::exit(1);
}
