{ config, lib, pkgs, ... }: {
	programs.starship = {
		enable = true;

		settings = {
			#"$schema" = "https://starship.rs/config-schema.json";
			format = "[](color_orange)$os$username[](bg:color_yellow fg:color_orange)$directory[](fg:color_yellow bg:color_bg3)$git_branch$git_status$git_metrics[](fg:color_bg3 bg:color_blue)$git_state$c$rust$nodejs$python[](fg:color_blue bg:color_bg3)$docker_context$jobs[](fg:color_bg3 bg:color_orange)$cmd_duration[](fg:color_orange bg:color_aqua)$time[ ](fg:color_aqua)$line_break$character";
			palette = "gruvbox_dark";
			palettes = {
				gruvbox_dark = {
				color_fg0 = "#fbf1c7";
				color_bg1 = "#3c3836";
				color_bg3 = "#665c54";
				color_blue = "#458588";
				color_aqua = "#689d6a";
				color_green = "#98971a";
				color_orange = "#d65d0e";
				color_purple = "#b16286";
				color_red = "#cc241d";
				color_yellow = "#d79921";
				};
			};
			os = {
				disabled = false;
				style = "bg:color_orange fg:color_fg0";
				symbols = {
				Windows = "󰍲 ";
				Ubuntu = "󰕈 ";
				SUSE = " ";
				Raspbian = "󰐿 ";
				Mint = "󰣭 ";
				Macos = " ";
				Manjaro = " ";
				Linux = "󰌽 ";
				Gentoo = "󰣨 ";
				Fedora = "󰣛 ";
				Alpine = " ";
				Amazon = " ";
				Android = " ";
				Arch = "󰣇 ";
				Artix = "󰣇 ";
				EndeavourOS = " ";
				CentOS = " ";
				Debian = "󰣚 ";
				Redhat = "󱄛 ";
				RedHatEnterprise = "󱄛 ";
				Pop = " ";
				};
			};
			username = {
				show_always = true;
				style_user = "bg:color_orange fg:color_fg0";
				style_root = "bg:color_orange fg:color_fg0";
				format = "[$user ]($style)";
			};
			directory = {
				style = "bg:color_yellow";
				format = "[ $path ]($style)";
				truncation_length = 3;
				truncation_symbol = "…/";
				substitutions = {
					Documents = "󰈙 ";
					documents = "󰈙 ";
					Downloads = " ";
					downloads = " ";
					Music = "󰝚 ";
					music = "󰝚 ";
					Pictures = " ";
					pictures = " ";
					Dropbox = " ";
					dropbox = " ";
				};
			};
			git_branch = {
				symbol = "";
				style = "bg:color_bg3";
				truncation_length = 24;
				format = "[[ $symbol $branch ](fg:color_fg0 bg:color_bg3)]($style)";
			};
			git_status = {
				style = "bg:color_bg3";
				format = "[[ $all_status $ahead_behind ](fg:color_fg0 bg:color_bg3)]($style)";
			};
			git_state = {
				style = "fg:color_fg0 bg:color_blue";
				format = "[ $state($progress_current/$progress_total) ]($style)";
			};
			nodejs = {
				disabled = true;
				symbol = "";
				style = "bg:color_blue";
				format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
			};
			c = {
				symbol = " ";
				style = "bg:color_blue";
				format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
			};
			rust = {
				symbol = "";
				style = "bg:color_blue";
				format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
			};
			python = {
				disabled = false;
				symbol = "";
				style = "bg:color_blue";
				format = "[[ $symbol( $version) ](fg:color_fg0 bg:color_blue)]($style)";
			};
			docker_context = {
				symbol = "";
				style = "bg:color_bg3";
				format = "[[ $symbol( $context) ](fg:#83a598 bg:color_bg3)]($style)";
			};
			jobs = {
				symbol = " ";
				style = "bg:color_bg3";
				number_threshold = 1;
				format = "[[ $symbol ](fg:color_fg0 bg:color_bg3)]($style)";
			};
			cmd_duration = {
				min_time = 500;
				style = "bg:color_orange";
				format = "[[ 󰔟$duration ](fg:color_fg0 bg:color_orange)]($style)";
			};
			time = {
				disabled = false;
				time_format = "%R";
				style = "bg:color_aqua";
				format = "[[  $time ](fg:color_fg0 bg:color_aqua)]($style)";
			};
			line_break = {
				disabled = false;
			};
			character = {
				disabled = false;
				success_symbol = "[](bold fg:color_green)";
				error_symbol = "[](bold fg:color_red)";
				vimcmd_symbol = "[](bold fg:color_green)";
				vimcmd_replace_one_symbol = "[](bold fg:color_purple)";
				vimcmd_replace_symbol = "[](bold fg:color_purple)";
				vimcmd_visual_symbol = "[](bold fg:color_yellow)";
			};
		};
	};
}
