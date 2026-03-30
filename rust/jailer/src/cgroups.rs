use anyhow::{Context, Result};
use std::fs;
use std::path::PathBuf;

const CGROUP_ROOT: &str = "/sys/fs/cgroup/infinity-node";

pub fn setup(name: &str, memory_limit_bytes: u64, cpu_shares: u64) -> Result<()> {
    let cgroup_path = PathBuf::from(CGROUP_ROOT).join(name);

    fs::create_dir_all(&cgroup_path)
        .context(format!("failed to create cgroup at {:?}", cgroup_path))?;

    fs::write(cgroup_path.join("memory.max"), memory_limit_bytes.to_string())
        .context("failed to set memory.max")?;

    fs::write(cgroup_path.join("memory.swap.max"), "0")
        .context("failed to disable swap")?;

    let cpu_weight = (cpu_shares * 100 / 1024).clamp(1, 10000);
    fs::write(cgroup_path.join("cpu.weight"), cpu_weight.to_string())
        .context("failed to set cpu.weight")?;

    Ok(())
}

pub fn enter(name: &str) -> Result<()> {
    let cgroup_path = PathBuf::from(CGROUP_ROOT).join(name);
    let pid = std::process::id();

    fs::write(cgroup_path.join("cgroup.procs"), pid.to_string())
        .context("failed to write pid to cgroup.procs")?;

    Ok(())
}

#[allow(dead_code)]
pub fn cleanup(name: &str) -> Result<()> {
    let cgroup_path = PathBuf::from(CGROUP_ROOT).join(name);
    if cgroup_path.exists() {
        fs::remove_dir(&cgroup_path)
            .context(format!("failed to remove cgroup {:?}", cgroup_path))?;
    }

    Ok(())
}
