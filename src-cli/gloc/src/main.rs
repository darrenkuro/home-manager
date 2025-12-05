/* ************************************************************************** */
/*                                                                            */
/*                                                        :::      ::::::::   */
/*   main.rs                                            :+:      :+:    :+:   */
/*                                                    +:+ +:+         +:+     */
/*   By: dlu <dlu@student.42berlin.de>              +#+  +:+       +#+        */
/*                                                +#+#+#+#+#+   +#+           */
/*   Created: 2025/06/20 20:22:25 by dlu               #+#    #+#             */
/*   Updated: 2025/06/20 20:23:09 by dlu              ###   ########.fr       */
/*                                                                            */
/* ************************************************************************** */

use clap::Parser;
use colored::*;
use std::process::{Command, Stdio};
use tempfile::tempdir;

#[derive(Parser)] // Turn Args into a command line parser, register --help and --version
#[command(author, version, about, long_about = None)]
struct Args {
    /// GitHub repo URL (e.g. https://github.com/evanw/esbuild)
    repo_url: String,
}

#[cfg(test)]
mod tests {
    use super::*;

    #[test]
    fn handles_plain_repo_name() {
        assert_eq!(
            normalize_repo_url("evanw/esbuild"),
            "https://github.com/evanw/esbuild"
        );
    }

    #[test]
    fn trims_leading_slash() {
        assert_eq!(
            normalize_repo_url("/evanw/esbuild"),
            "https://github.com/evanw/esbuild"
        );
    }

    #[test]
    fn removes_git_suffix() {
        assert_eq!(
            normalize_repo_url("evanw/esbuild.git"),
            "https://github.com/evanw/esbuild"
        );
    }

    #[test]
    fn leaves_full_github_url() {
        assert_eq!(
            normalize_repo_url("https://github.com/evanw/esbuild"),
            "https://github.com/evanw/esbuild"
        );
    }
}

fn normalize_repo_url(input: &str) -> String {
    let trimmed = input.trim();

    if trimmed.starts_with("https://github.com/") || trimmed.starts_with("git@github.com:") {
        trimmed.to_string()
    } else {
        format!(
            "https://github.com/{}",
            trimmed.trim_start_matches('/').trim_end_matches(".git")
        )
    }
}

fn main() {
    let args = Args::parse();
    let repo_url = normalize_repo_url(&args.repo_url);

    let tmp_dir = tempdir().expect("❌ Failed to create temp dir");

    println!("📥 Cloning {}...", repo_url.green());
    let clone_status = Command::new("git")
        .args([
            "clone",
            "--depth",
            "1", // Clone only the latest commit
            &repo_url,
            tmp_dir.path().to_str().unwrap(),
        ])
        .stdout(Stdio::null())
        .stderr(Stdio::inherit())
        .status()
        .expect("❌ Failed to run git");

    if !clone_status.success() {
        eprintln!("❌ Git clone failed");
        std::process::exit(1);
    }

    println!("📊 Running {}...", "tokei".blue());
    let tokei_status = Command::new("tokei")
        .arg(tmp_dir.path())
        .status()
        .expect("❌ Failed to run tokei");

    if !tokei_status.success() {
        eprintln!("❌ tokei failed");
        std::process::exit(1);
    }

    println!(
        "🧹 Cleaned up {}",
        tmp_dir.path().display().to_string().yellow()
    );

    // `tmp_dir` is deleted automatically here
}
