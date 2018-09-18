# cmder-powerline
powerline-style prompt for cmder

![screenshot of cmder-powerline](https://i.imgur.com/Tfe4E3f.png)

## Features
* Git branch/merge display
  * Git index clean/dirty display (optional, off by default)
* Mercurial branch display
* NPM package version display
* Customizable date/time display
* That's about it, really. More features were sacrificed in the name of performance. Features such
  as displaying whether the version control work tree is clean/dirty, or checking the Git index,
  which are present in other prompt addons, require recomputing the repository's status every time
  the prompt is displayed, which is very slow, so they were omitted.

## Usage

### Requirements
* A [Nerd Fonts](https://nerdfonts.com/)-patched font. (I use
  [SauceCodePro NF](https://github.com/ryanoasis/nerd-fonts/tree/master/patched-fonts/SourceCodePro/Regular/complete),
  since it includes
  a good part of the Unicode pseudographics)
* Mercurial in your PATH (for the respective functionality)

### Installation
1. If you haven't already, go to **General -> Fonts** in your Cmder settings and set your font to
   a Nerd Fonts-patched font.
    * If you don't want to change your console font, you might want to use the patched font as an
      alternative font, where it will only be used to draw the icons. In that case, follow the
      steps:
    1. Tick the Alternative font box and set the name of your Nerd Font that will be used as an
       alternative.
       
       You should have already installed the font or placed it in the ConEmu (not Cmder!)
       directory by now. You'll also need to restart Cmder after installing the font. If you don't
       do so, Cmder will spit an error at you.
       
    1. In the Unicode range input field, put the following and hit Apply:
       
       `2013-25C4;2665;26A1;2B58;E000-E00D;E0A0-E0A3;E0B0-E0C8;E0CC-E0D2;E0D4;E200-E2A9;E5FA-E62B;E700-E7C5;F000-F2E0;F300-F313;F400-F4A8;F500-FD46;`
       
       These ranges encompass all Unicode pseudographics, and all Nerd Fonts icons.
1. Clone `https://github.com/uwx/cmder-powerline.git` to your Cmder directory. Remember to clone
   the submodules as well:
   ```cmd
   git clone https://github.com/uwx/cmder-powerline --recurse-submodules
   ```
1. In your Cmder directory's `config` folder, create a lua file (with any name, such as `init.lua`)
1. In the file, write:
   ```lua
   dofile(clink.get_env('ClinkLuaPath') .. '/clink.lua')
   ```
1. At the end of your `user-profile.cmd` file (same folder as your lua file), write:
   ```cmd
   set ClinkLuaPath=%CMDER_ROOT%\cmder-powerline
   ```
   If you cloned `cmder-powerline` to a different directory, replace `%CMDER_ROOT%\cmder-powerline`
   with the full path to that directory. Otherwise, the default will work.
1. Spawn a new Cmder window/tab, and if you did everything right, the new prompt will show up!

### Troubleshooting

  * **`module 'clink-completions.modules.JSON' not found`:**
    
    You didn't clone the repository's submodules. Please see [Installation](#installation).

  * **`cannot open ***\cmder-powerline/clink.lua: No such file or directory`:**
  
    You didn't clone the repository, or you set the wrong `ClinkLuaPath`. Please see
    [Installation](#installation).

  * **All the special characters are boxes!**
    
    You're not using a Nerd Fonts-patched font. Please see [Installation](#installation).

  * **It's too slow!**
  
    This happens in Mercurial repos. There is a delay of about 0.3 seconds to identify the current
    branch. This is a problem in (I think) every powerline prompt addon, even for non-Windows
    systems.
    
    If you're alright with crippling the Mercurial branch display to save a few tenths of
    a second, you can comment this line (with `--`) at the bottom of `clink.lua`:
    ```lua
    make_section_hg,
    ```
    Then, you can press `Ctrl+Q` in your prompt to reload the script, or just start a new prompt.
    This will disable Mercurial branch display entirely.

### See also
cmder-powerline was inspired by these prompts, so go check them out:

[AmrEldib/cmder-powerline-prompt](https://github.com/AmrEldib/cmder-powerline-prompt)  
[fredjoseph/cmder-powerline-prompt](https://github.com/fredjoseph/cmder-powerline-prompt)
