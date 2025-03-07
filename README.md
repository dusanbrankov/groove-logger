# Groove Logger

This is a Bash script to log and track the recent song history of selected [SomaFM.com](https://somafm.com/) radio channels: [Groove Salad](https://somafm.com/groovesalad/) and [Groove Salad Classic](https://somafm.com/gsclassic/). The channel list can be changed using the `SFM_CHANNELS` environment variable.

- Retrieves song history and tracks changes
- Saves song names to disc with play time converted to the user's local time

## Installation

1. Make sure that [html-xml-utils](https://www.w3.org/Tools/HTML-XML-utils/) is installed. On Debian(-based) distributions, it can be installed using `apt`:

```sh
sudo apt install -y html-xml-utils
```

2. Clone this repository and make the script executable.

```sh
git clone https://github.com/dusanbrankov/groove-logger.git
cd groove-logger
chmod u+x groove-logger.sh
```

3. Move the script to one of your `PATH` directories for easy access:

```sh
sudo mv groove-logger.sh /usr/local/bin/groove-logger
```

## Usage

```sh
groove-logger
```

### Environment variables

These are the environment variables with their default values used in the script:

```sh
# Path to the directory for storing the song history
SFM_LOG_DIR=~/groove-logger

# Interval at which the song history is updated
# Suffix may be 's' for seconds, 'm' for minutes, 'h' for hours or 'd' for days
SFM_CHECK_INTERVAL=5m

# Radio channels to follow
SFM_CHANNELS=groovesalad,gsclassic
```

All available channels are listed on [SomaFM.com](https://somafm.com/). To log the song history of other channels, the `SFM_CHANNELS` variable must be set with the channel names taken from the respective URL.

For example, to follow only the [SF 10-33](https://somafm.com/sf1033/) and [Fluid](https://somafm.com/fluid/) channels:

```sh
SFM_CHANNELS=sf1033,fluid groove-logger
```

> [!NOTE]
> The channel names *must match the last URL path segment of the links*, e.g. `sf1033` is taken from `https://somafm.com/sf1033/`.

The environment variables can also be set in your shell configuration file, for example:

```sh
export SFM_LOG_DIR=~/my-groove-logger
export SFM_CHECK_INTERVAL=1h
export SFM_CHANNELS=groovesalad,gsclassic,fluid
```

## Groove Player

To play and switch between radio channels from the command line, I added the following function to my `.bashrc` using `vlc` and `fzf`. It can be especially useful when running the player remotely.

Feel free to use or modify it.

```bash
groove-player() {
    local stations choice url
    stations=(
        "Groove Salad: https://somafm.com/groovesalad130.pls"
        "Groove Salad Cassic: https://somafm.com/gsclassic130.pls"
        "Drone Zone: https://somafm.com/dronezone130.pls"
        "Deep Space One: https://somafm.com/deepspaceone130.pls"
        "Fluid: https://somafm.com/fluid130.pls"
        "Varporwave: https://somafm.com/vaporwaves130.pls"
        "SF 10-33: https://somafm.com/sf1033130.pls"
        "DEF CON: https://somafm.com/defcon130.pls"
    )
    choice=$(printf '%s\n' "${stations[@]}" | fzf +m --disabled) || return
    url="$(grep -o 'http.*' <<< "$choice")"

    printf "Playing: %s\n" "$choice"
    cvlc "$url"
}
# Usage: <Alt-p>
bind -x '"\ep":"groove-player"' 
```
