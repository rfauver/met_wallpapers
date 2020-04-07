# met_wallpapers
![irises](https://user-images.githubusercontent.com/7726851/78621135-bb0d4e80-7836-11ea-992d-9fee3f27474f.jpg)

Ruby script to download wallpapers from the collection of the Metropolitan Mueum of Art. By default downloads a 1920x1080 image with a black background behind the original image and a white caption of the title, artist, and year of the work.

## Prerequisites

- Ruby version 2.3 or later
- [Bundler](https://bundler.io/)
- ImageMagick version 6.7.7 or later. Installation instructions (for use with Rmagick) can be found [here](https://github.com/rmagick/rmagick#prerequisites)
- A copy of `MetObjects.csv` from the [The Metropolitan Museum of Art Open Access repo](https://github.com/metmuseum/openaccess) placed in the directory where you run this script

## Usage

Run `bundle install` (once) to download dependencies.

Run with `ruby met_wallpapers.rb`

Wallpapers will be downloaded into a `./wallpapers` folder, and the script will run until the limit paramter is reached or all matching images are downloaded.

### Downloading specific work

In order to download a specific work, you can use the `--id` option. You can search through the catalog on the [Met Musem website](https://www.metmuseum.org/art/collection/search). The id can be found in the URL of the individual work after `/search/`. For example, in order to download https://www.metmuseum.org/art/collection/search/459116, run `ruby met_wallpapers.rb --id 459116`.

## Options
| Option               | Default   | Description                                                                                                      |
|----------------------|-----------|------------------------------------------------------------------------------------------------------------------|
| `--id`               |           | Download a specific work                                                                                         |
| `--width`            | `1920`    | Wallpaper output width, in pixels                                                                                |
| `--height`           | `1080`    | Wallpaper output height, in pixels                                                                               |
| `-l`, `--limit`      |           | Limit number of wallpapers downloaded                                                                            |
| `-d`, `--department` |           | Filter to museum department in [this list](https://collectionapi.metmuseum.org/public/collection/v1/departments) |
| `--landscape`        | `false`   | Restrict to landscape orientation images only                                                                    |
| `--portrait`         | `false`   | Restrict to portrait orientation images only                                                                     |
| `--background-color` | `'black'` | Wallpaper background color string, e.g. `'#0c1087'`, `'pink'`                                                    |
| `--text-color`       | `'white'` | Caption text color string, e.g. `'#0c1087'`, `'pink'`                                                            |
| `-h`, `--help`       |           | Show help menu                                                                                                   |

## Examples
`ruby met_wallpapers.rb`

![plate](https://user-images.githubusercontent.com/7726851/78618550-bd1fdf00-782f-11ea-9d09-6bb4532ed954.jpg)

`ruby met_wallpapers.rb --width 1080 --height 1920`

![saint_anthony_the_abbot_in_the_wilderness](https://user-images.githubusercontent.com/7726851/78618893-9ca45480-7830-11ea-86d8-ab58f04e0978.jpg)

`ruby met_wallpapers.rb --background-color '#2F4F4F' --text-color 'DarkSlateGrey'`

![pen_box_(qalamdan)_depicting_shah_isma'il_in_a_battle_against_the_uzbeks](https://user-images.githubusercontent.com/7726851/78619610-97e0a000-7832-11ea-8326-3b1a4e38cbf7.jpg)

`ruby met_wallpapers.rb --width 3840 --height 2160 -d 'european paintings'`

![the_siesta](https://user-images.githubusercontent.com/7726851/78619993-a7acb400-7833-11ea-8579-0a51449d9280.jpg)

`ruby met_wallpapers.rb -d 'photographs'`

![temple_of_edfu](https://user-images.githubusercontent.com/7726851/78620250-4e915000-7834-11ea-9b8d-b2c1d66e2740.jpg)

## License

[MIT](LICENSE)

Metropolitan Museum of Art Open Access API licensed with [CC0](https://creativecommons.org/publicdomain/zero/1.0/). Images downloaded by this script are limited to those marked by the API as in the Public Domain.

[Met Open Access Policy](https://www.metmuseum.org/about-the-met/policies-and-documents/image-resources)
