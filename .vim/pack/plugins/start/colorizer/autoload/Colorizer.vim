" Plugin:       Highlight Colornames and Values
" Maintainer:   Christian Brabandt <cb@256bit.org>
" URL:          http://www.github.com/chrisbra/color_highlight
" Last Change: Thu, 15 Jan 2015 21:49:17 +0100
" Licence:      Vim License (see :h License)
" Version:      0.11
" GetLatestVimScripts: 3963 11 :AutoInstall: Colorizer.vim
"
" This plugin was inspired by the css_color.vim plugin from Nikolaus Hofer.
" Changes made: - make terminal colors work more reliably and with all
"                 color terminals
"               - performance improvements, coloring is almost instantenously
"               - detect rgb colors like this: rgb(R,G,B)
"               - detect hvl coloring: hvl(H,V,L)
"               - fix small bugs
"               - Color ANSI Term values and hide terminal escape sequences

" Init some variables "{{{1
let s:cpo_save = &cpo
set cpo&vim

" the 6 value iterations in the xterm color cube "{{{2
let s:valuerange6 = [ 0x00, 0x5F, 0x87, 0xAF, 0xD7, 0xFF ]

"" the 4 value iterations in the 88 color xterm cube "{{{2
let s:valuerange4 = [ 0x00, 0x8B, 0xCD, 0xFF ]
"
"" 16 basic colors "{{{2
let s:basic16 = [
    \ [ 0x00, 0x00, 0x00 ],
    \ [ 0xCD, 0x00, 0x00 ],
    \ [ 0x00, 0xCD, 0x00 ],
    \ [ 0xCD, 0xCD, 0x00 ],
    \ [ 0x00, 0x00, 0xEE ],
    \ [ 0xCD, 0x00, 0xCD ],
    \ [ 0x00, 0xCD, 0xCD ],
    \ [ 0xE5, 0xE5, 0xE5 ],
    \ [ 0x7F, 0x7F, 0x7F ],
    \ [ 0xFF, 0x00, 0x00 ],
    \ [ 0x00, 0xFF, 0x00 ],
    \ [ 0xFF, 0xFF, 0x00 ],
    \ [ 0x5C, 0x5C, 0xFF ],
    \ [ 0xFF, 0x00, 0xFF ],
    \ [ 0x00, 0xFF, 0xFF ],
    \ [ 0xFF, 0xFF, 0xFF ]
    \ ]

" Cygwin / Window console / ConEmu has different color codes
if ($ComSpec =~# '^\%(command\.com\|cmd\.exe\)$' &&
    \ !s:HasGui()) ||
    \ (exists("$ConEmuPID") &&
    \ $ConEmuANSI ==# "OFF") ||
    \ ($TERM ==# 'cygwin' && &t_Co == 16)  " Cygwin terminal

    " command.com/ConEmu Color Cube (currently only supports 16 colors)
    let s:basic16 = [
    \ [ 0x00, 0x00, 0x00 ],
    \ [ 0x00, 0x00, 0x80 ],
    \ [ 0x00, 0x80, 0x00 ],
    \ [ 0x00, 0x80, 0x80 ],
    \ [ 0x80, 0x00, 0x00 ],
    \ [ 0x80, 0x00, 0x80 ],
    \ [ 0xFF, 0xFF, 0x00 ],
    \ [ 0xFF, 0xFF, 0xFF ],
    \ [ 0xC0, 0xC0, 0xC0 ],
    \ [ 0x00, 0x00, 0xFF ],
    \ [ 0x00, 0xFF, 0x00 ],
    \ [ 0x00, 0xFF, 0xFF ],
    \ [ 0xFF, 0x00, 0x00 ],
    \ [ 0xFF, 0x00, 0xFF ],
    \ [ 0xFF, 0xFF, 0x00 ],
    \ [ 0xFF, 0xFF, 0xFF ]
    \ ]
    let &t_Co=16
endif

" xterm-8 colors "{{{2
let s:xterm_8colors = {
\ 'black':          '#000000',
\ 'darkblue':       '#00008B',
\ 'darkgreen':      '#00CD00',
\ 'darkcyan':       '#00CDCD',
\ 'darkred':        '#CD0000',
\ 'darkmagenta':    '#8B008B',
\ 'brown':          '#CDCD00',
\ 'darkyellow':     '#CDCD00',
\ 'lightgrey':      '#E5E5E5',
\ 'lightgray':      '#E5E5E5',
\ 'gray':           '#E5E5E5',
\ 'grey':           '#E5E5E5'
\ }

" xterm-16 colors "{{{2
let s:xterm_16colors = {
\ 'darkgrey':       '#7F7F7F',
\ 'darkgray':       '#7F7F7F',
\ 'blue':           '#5C5CFF',
\ 'lightblue':      '#5C5CFF',
\ 'green':          '#00FF00',
\ 'lightgreen':     '#00FF00',
\ 'cyan':           '#00FFFF',
\ 'lightcyan':      '#00FFFF',
\ 'red':            '#FF0000',
\ 'lightred':       '#FF0000',
\ 'magenta':        '#FF00FF',
\ 'lightmagenta':   '#FF00FF',
\ 'yellow':         '#FFFF00',
\ 'lightyellow':    '#FFFF00',
\ 'white':          '#FFFFFF',
\ }
" add the items from the 8 color xterm variable to the 16 color xterm
call extend(s:xterm_16colors, s:xterm_8colors)

" W3C Colors "{{{2
let s:w3c_color_names = {
\ 'aliceblue': '#F0F8FF',
\ 'antiquewhite': '#FAEBD7',
\ 'aqua': '#00FFFF',
\ 'aquamarine': '#7FFFD4',
\ 'azure': '#F0FFFF',
\ 'beige': '#F5F5DC',
\ 'bisque': '#FFE4C4',
\ 'black': '#000000',
\ 'blanchedalmond': '#FFEBCD',
\ 'blue': '#0000FF',
\ 'blueviolet': '#8A2BE2',
\ 'brown': '#A52A2A',
\ 'burlywood': '#DEB887',
\ 'cadetblue': '#5F9EA0',
\ 'chartreuse': '#7FFF00',
\ 'chocolate': '#D2691E',
\ 'coral': '#FF7F50',
\ 'cornflowerblue': '#6495ED',
\ 'cornsilk': '#FFF8DC',
\ 'crimson': '#DC143C',
\ 'cyan': '#00FFFF',
\ 'darkblue': '#00008B',
\ 'darkcyan': '#008B8B',
\ 'darkgoldenrod': '#B8860B',
\ 'darkgray': '#A9A9A9',
\ 'darkgreen': '#006400',
\ 'darkkhaki': '#BDB76B',
\ 'darkmagenta': '#8B008B',
\ 'darkolivegreen': '#556B2F',
\ 'darkorange': '#FF8C00',
\ 'darkorchid': '#9932CC',
\ 'darkred': '#8B0000',
\ 'darksalmon': '#E9967A',
\ 'darkseagreen': '#8FBC8F',
\ 'darkslateblue': '#483D8B',
\ 'darkslategray': '#2F4F4F',
\ 'darkturquoise': '#00CED1',
\ 'darkviolet': '#9400D3',
\ 'deeppink': '#FF1493',
\ 'deepskyblue': '#00BFFF',
\ 'dimgray': '#696969',
\ 'dodgerblue': '#1E90FF',
\ 'firebrick': '#B22222',
\ 'floralwhite': '#FFFAF0',
\ 'forestgreen': '#228B22',
\ 'fuchsia': '#FF00FF',
\ 'gainsboro': '#DCDCDC',
\ 'ghostwhite': '#F8F8FF',
\ 'gold': '#FFD700',
\ 'goldenrod': '#DAA520',
\ 'gray': '#808080',
\ 'green': '#008000',
\ 'greenyellow': '#ADFF2F',
\ 'honeydew': '#F0FFF0',
\ 'hotpink': '#FF69B4',
\ 'indianred': '#CD5C5C',
\ 'indigo': '#4B0082',
\ 'ivory': '#FFFFF0',
\ 'khaki': '#F0E68C',
\ 'lavender': '#E6E6FA',
\ 'lavenderblush': '#FFF0F5',
\ 'lawngreen': '#7CFC00',
\ 'lemonchiffon': '#FFFACD',
\ 'lightblue': '#ADD8E6',
\ 'lightcoral': '#F08080',
\ 'lightcyan': '#E0FFFF',
\ 'lightgoldenrodyellow': '#FAFAD2',
\ 'lightgray': '#D3D3D3',
\ 'lightgreen': '#90EE90',
\ 'lightpink': '#FFB6C1',
\ 'lightsalmon': '#FFA07A',
\ 'lightseagreen': '#20B2AA',
\ 'lightskyblue': '#87CEFA',
\ 'lightslategray': '#778899',
\ 'lightsteelblue': '#B0C4DE',
\ 'lightyellow': '#FFFFE0',
\ 'lime': '#00FF00',
\ 'limegreen': '#32CD32',
\ 'linen': '#FAF0E6',
\ 'magenta': '#FF00FF',
\ 'maroon': '#800000',
\ 'mediumaquamarine': '#66CDAA',
\ 'mediumblue': '#0000CD',
\ 'mediumorchid': '#BA55D3',
\ 'mediumpurple': '#9370D8',
\ 'mediumseagreen': '#3CB371',
\ 'mediumslateblue': '#7B68EE',
\ 'mediumspringgreen': '#00FA9A',
\ 'mediumturquoise': '#48D1CC',
\ 'mediumvioletred': '#C71585',
\ 'midnightblue': '#191970',
\ 'mintcream': '#F5FFFA',
\ 'mistyrose': '#FFE4E1',
\ 'moccasin': '#FFE4B5',
\ 'navajowhite': '#FFDEAD',
\ 'navy': '#000080',
\ 'oldlace': '#FDF5E6',
\ 'olive': '#808000',
\ 'olivedrab': '#6B8E23',
\ 'orange': '#FFA500',
\ 'orangered': '#FF4500',
\ 'orchid': '#DA70D6',
\ 'palegoldenrod': '#EEE8AA',
\ 'palegreen': '#98FB98',
\ 'paleturquoise': '#AFEEEE',
\ 'palevioletred': '#D87093',
\ 'papayawhip': '#FFEFD5',
\ 'peachpuff': '#FFDAB9',
\ 'peru': '#CD853F',
\ 'pink': '#FFC0CB',
\ 'plum': '#DDA0DD',
\ 'powderblue': '#B0E0E6',
\ 'purple': '#800080',
\ 'red': '#FF0000',
\ 'rosybrown': '#BC8F8F',
\ 'royalblue': '#4169E1',
\ 'saddlebrown': '#8B4513',
\ 'salmon': '#FA8072',
\ 'sandybrown': '#F4A460',
\ 'seagreen': '#2E8B57',
\ 'seashell': '#FFF5EE',
\ 'sienna': '#A0522D',
\ 'silver': '#C0C0C0',
\ 'skyblue': '#87CEEB',
\ 'slateblue': '#6A5ACD',
\ 'slategray': '#708090',
\ 'snow': '#FFFAFA',
\ 'springgreen': '#00FF7F',
\ 'steelblue': '#4682B4',
\ 'tan': '#D2B48C',
\ 'teal': '#008080',
\ 'thistle': '#D8BFD8',
\ 'tomato': '#FF6347',
\ 'turquoise': '#40E0D0',
\ 'violet': '#EE82EE',
\ 'wheat': '#F5DEB3',
\ 'white': '#FFFFFF',
\ 'whitesmoke': '#F5F5F5',
\ 'yellow': '#FFFF00',
\ 'yellowgreen': '#9ACD32'
\ }

" X11 color names taken from "{{{2
" http://cvsweb.xfree86.org/cvsweb/*checkout*/xc/programs/rgb/rgb.txt?rev=1.2
let s:x11_color_names = {
\ 'snow': '#FFFAFA',
\ 'ghostwhite': '#F8F8FF',
\ 'whitesmoke': '#F5F5F5',
\ 'gainsboro': '#DCDCDC',
\ 'floralwhite': '#FFFAF0',
\ 'oldlace': '#FDF5E6',
\ 'linen': '#FAF0E6',
\ 'antiquewhite': '#FAEBD7',
\ 'papayawhip': '#FFEFD5',
\ 'blanchedalmond': '#FFEBCD',
\ 'bisque': '#FFE4C4',
\ 'peachpuff': '#FFDAB9',
\ 'navajowhite': '#FFDEAD',
\ 'moccasin': '#FFE4B5',
\ 'cornsilk': '#FFF8DC',
\ 'ivory': '#FFFFF0',
\ 'lemonchiffon': '#FFFACD',
\ 'seashell': '#FFF5EE',
\ 'honeydew': '#F0FFF0',
\ 'mintcream': '#F5FFFA',
\ 'azure': '#F0FFFF',
\ 'aliceblue': '#F0F8FF',
\ 'lavender': '#E6E6FA',
\ 'lavenderblush': '#FFF0F5',
\ 'mistyrose': '#FFE4E1',
\ 'white': '#FFFFFF',
\ 'black': '#000000',
\ 'darkslategray': '#2F4F4F',
\ 'darkslategrey': '#2F4F4F',
\ 'dimgray': '#696969',
\ 'dimgrey': '#696969',
\ 'slategray': '#708090',
\ 'slategrey': '#708090',
\ 'lightslategray': '#778899',
\ 'lightslategrey': '#778899',
\ 'gray': '#BEBEBE',
\ 'grey': '#BEBEBE',
\ 'lightgrey': '#D3D3D3',
\ 'lightgray': '#D3D3D3',
\ 'midnightblue': '#191970',
\ 'navy': '#000080',
\ 'navyblue': '#000080',
\ 'cornflowerblue': '#6495ED',
\ 'darkslateblue': '#483D8B',
\ 'slateblue': '#6A5ACD',
\ 'mediumslateblue': '#7B68EE',
\ 'lightslateblue': '#8470FF',
\ 'mediumblue': '#0000CD',
\ 'royalblue': '#4169E1',
\ 'blue': '#0000FF',
\ 'dodgerblue': '#1E90FF',
\ 'deepskyblue': '#00BFFF',
\ 'skyblue': '#87CEEB',
\ 'lightskyblue': '#87CEFA',
\ 'steelblue': '#4682B4',
\ 'lightsteelblue': '#B0C4DE',
\ 'lightblue': '#ADD8E6',
\ 'powderblue': '#B0E0E6',
\ 'paleturquoise': '#AFEEEE',
\ 'darkturquoise': '#00CED1',
\ 'mediumturquoise': '#48D1CC',
\ 'turquoise': '#40E0D0',
\ 'cyan': '#00FFFF',
\ 'lightcyan': '#E0FFFF',
\ 'cadetblue': '#5F9EA0',
\ 'mediumaquamarine': '#66CDAA',
\ 'aquamarine': '#7FFFD4',
\ 'darkgreen': '#006400',
\ 'darkolivegreen': '#556B2F',
\ 'darkseagreen': '#8FBC8F',
\ 'seagreen': '#2E8B57',
\ 'mediumseagreen': '#3CB371',
\ 'lightseagreen': '#20B2AA',
\ 'palegreen': '#98FB98',
\ 'springgreen': '#00FF7F',
\ 'lawngreen': '#7CFC00',
\ 'green': '#00FF00',
\ 'chartreuse': '#7FFF00',
\ 'mediumspringgreen': '#00FA9A',
\ 'greenyellow': '#ADFF2F',
\ 'limegreen': '#32CD32',
\ 'yellowgreen': '#9ACD32',
\ 'forestgreen': '#228B22',
\ 'olivedrab': '#6B8E23',
\ 'darkkhaki': '#BDB76B',
\ 'khaki': '#F0E68C',
\ 'palegoldenrod': '#EEE8AA',
\ 'lightgoldenrodyellow': '#FAFAD2',
\ 'lightyellow': '#FFFFE0',
\ 'yellow': '#FFFF00',
\ 'gold': '#FFD700',
\ 'lightgoldenrod': '#EEDD82',
\ 'goldenrod': '#DAA520',
\ 'darkgoldenrod': '#B8860B',
\ 'rosybrown': '#BC8F8F',
\ 'indianred': '#CD5C5C',
\ 'saddlebrown': '#8B4513',
\ 'sienna': '#A0522D',
\ 'peru': '#CD853F',
\ 'burlywood': '#DEB887',
\ 'beige': '#F5F5DC',
\ 'wheat': '#F5DEB3',
\ 'sandybrown': '#F4A460',
\ 'tan': '#D2B48C',
\ 'chocolate': '#D2691E',
\ 'firebrick': '#B22222',
\ 'brown': '#A52A2A',
\ 'darksalmon': '#E9967A',
\ 'salmon': '#FA8072',
\ 'lightsalmon': '#FFA07A',
\ 'orange': '#FFA500',
\ 'darkorange': '#FF8C00',
\ 'coral': '#FF7F50',
\ 'lightcoral': '#F08080',
\ 'tomato': '#FF6347',
\ 'orangered': '#FF4500',
\ 'red': '#FF0000',
\ 'hotpink': '#FF69B4',
\ 'deeppink': '#FF1493',
\ 'pink': '#FFC0CB',
\ 'lightpink': '#FFB6C1',
\ 'palevioletred': '#DB7093',
\ 'maroon': '#B03060',
\ 'mediumvioletred': '#C71585',
\ 'violetred': '#D02090',
\ 'magenta': '#FF00FF',
\ 'violet': '#EE82EE',
\ 'plum': '#DDA0DD',
\ 'orchid': '#DA70D6',
\ 'mediumorchid': '#BA55D3',
\ 'darkorchid': '#9932CC',
\ 'darkviolet': '#9400D3',
\ 'blueviolet': '#8A2BE2',
\ 'purple': '#A020F0',
\ 'mediumpurple': '#9370DB',
\ 'thistle': '#D8BFD8',
\ 'snow1': '#FFFAFA',
\ 'snow2': '#EEE9E9',
\ 'snow3': '#CDC9C9',
\ 'snow4': '#8B8989',
\ 'seashell1': '#FFF5EE',
\ 'seashell2': '#EEE5DE',
\ 'seashell3': '#CDC5BF',
\ 'seashell4': '#8B8682',
\ 'antiquewhite1': '#FFEFDB',
\ 'antiquewhite2': '#EEDFCC',
\ 'antiquewhite3': '#CDC0B0',
\ 'antiquewhite4': '#8B8378',
\ 'bisque1': '#FFE4C4',
\ 'bisque2': '#EED5B7',
\ 'bisque3': '#CDB79E',
\ 'bisque4': '#8B7D6B',
\ 'peachpuff1': '#FFDAB9',
\ 'peachpuff2': '#EECBAD',
\ 'peachpuff3': '#CDAF95',
\ 'peachpuff4': '#8B7765',
\ 'navajowhite1': '#FFDEAD',
\ 'navajowhite2': '#EECFA1',
\ 'navajowhite3': '#CDB38B',
\ 'navajowhite4': '#8B795E',
\ 'lemonchiffon1': '#FFFACD',
\ 'lemonchiffon2': '#EEE9BF',
\ 'lemonchiffon3': '#CDC9A5',
\ 'lemonchiffon4': '#8B8970',
\ 'cornsilk1': '#FFF8DC',
\ 'cornsilk2': '#EEE8CD',
\ 'cornsilk3': '#CDC8B1',
\ 'cornsilk4': '#8B8878',
\ 'ivory1': '#FFFFF0',
\ 'ivory2': '#EEEEE0',
\ 'ivory3': '#CDCDC1',
\ 'ivory4': '#8B8B83',
\ 'honeydew1': '#F0FFF0',
\ 'honeydew2': '#E0EEE0',
\ 'honeydew3': '#C1CDC1',
\ 'honeydew4': '#838B83',
\ 'lavenderblush1': '#FFF0F5',
\ 'lavenderblush2': '#EEE0E5',
\ 'lavenderblush3': '#CDC1C5',
\ 'lavenderblush4': '#8B8386',
\ 'mistyrose1': '#FFE4E1',
\ 'mistyrose2': '#EED5D2',
\ 'mistyrose3': '#CDB7B5',
\ 'mistyrose4': '#8B7D7B',
\ 'azure1': '#F0FFFF',
\ 'azure2': '#E0EEEE',
\ 'azure3': '#C1CDCD',
\ 'azure4': '#838B8B',
\ 'slateblue1': '#836FFF',
\ 'slateblue2': '#7A67EE',
\ 'slateblue3': '#6959CD',
\ 'slateblue4': '#473C8B',
\ 'royalblue1': '#4876FF',
\ 'royalblue2': '#436EEE',
\ 'royalblue3': '#3A5FCD',
\ 'royalblue4': '#27408B',
\ 'blue1': '#0000FF',
\ 'blue2': '#0000EE',
\ 'blue3': '#0000CD',
\ 'blue4': '#00008B',
\ 'dodgerblue1': '#1E90FF',
\ 'dodgerblue2': '#1C86EE',
\ 'dodgerblue3': '#1874CD',
\ 'dodgerblue4': '#104E8B',
\ 'steelblue1': '#63B8FF',
\ 'steelblue2': '#5CACEE',
\ 'steelblue3': '#4F94CD',
\ 'steelblue4': '#36648B',
\ 'deepskyblue1': '#00BFFF',
\ 'deepskyblue2': '#00B2EE',
\ 'deepskyblue3': '#009ACD',
\ 'deepskyblue4': '#00688B',
\ 'skyblue1': '#87CEFF',
\ 'skyblue2': '#7EC0EE',
\ 'skyblue3': '#6CA6CD',
\ 'skyblue4': '#4A708B',
\ 'lightskyblue1': '#B0E2FF',
\ 'lightskyblue2': '#A4D3EE',
\ 'lightskyblue3': '#8DB6CD',
\ 'lightskyblue4': '#607B8B',
\ 'slategray1': '#C6E2FF',
\ 'slategray2': '#B9D3EE',
\ 'slategray3': '#9FB6CD',
\ 'slategray4': '#6C7B8B',
\ 'lightsteelblue1': '#CAE1FF',
\ 'lightsteelblue2': '#BCD2EE',
\ 'lightsteelblue3': '#A2B5CD',
\ 'lightsteelblue4': '#6E7B8B',
\ 'lightblue1': '#BFEFFF',
\ 'lightblue2': '#B2DFEE',
\ 'lightblue3': '#9AC0CD',
\ 'lightblue4': '#68838B',
\ 'lightcyan1': '#E0FFFF',
\ 'lightcyan2': '#D1EEEE',
\ 'lightcyan3': '#B4CDCD',
\ 'lightcyan4': '#7A8B8B',
\ 'paleturquoise1': '#BBFFFF',
\ 'paleturquoise2': '#AEEEEE',
\ 'paleturquoise3': '#96CDCD',
\ 'paleturquoise4': '#668B8B',
\ 'cadetblue1': '#98F5FF',
\ 'cadetblue2': '#8EE5EE',
\ 'cadetblue3': '#7AC5CD',
\ 'cadetblue4': '#53868B',
\ 'turquoise1': '#00F5FF',
\ 'turquoise2': '#00E5EE',
\ 'turquoise3': '#00C5CD',
\ 'turquoise4': '#00868B',
\ 'cyan1': '#00FFFF',
\ 'cyan2': '#00EEEE',
\ 'cyan3': '#00CDCD',
\ 'cyan4': '#008B8B',
\ 'darkslategray1': '#97FFFF',
\ 'darkslategray2': '#8DEEEE',
\ 'darkslategray3': '#79CDCD',
\ 'darkslategray4': '#528B8B',
\ 'aquamarine1': '#7FFFD4',
\ 'aquamarine2': '#76EEC6',
\ 'aquamarine3': '#66CDAA',
\ 'aquamarine4': '#458B74',
\ 'darkseagreen1': '#C1FFC1',
\ 'darkseagreen2': '#B4EEB4',
\ 'darkseagreen3': '#9BCD9B',
\ 'darkseagreen4': '#698B69',
\ 'seagreen1': '#54FF9F',
\ 'seagreen2': '#4EEE94',
\ 'seagreen3': '#43CD80',
\ 'seagreen4': '#2E8B57',
\ 'palegreen1': '#9AFF9A',
\ 'palegreen2': '#90EE90',
\ 'palegreen3': '#7CCD7C',
\ 'palegreen4': '#548B54',
\ 'springgreen1': '#00FF7F',
\ 'springgreen2': '#00EE76',
\ 'springgreen3': '#00CD66',
\ 'springgreen4': '#008B45',
\ 'green1': '#00FF00',
\ 'green2': '#00EE00',
\ 'green3': '#00CD00',
\ 'green4': '#008B00',
\ 'chartreuse1': '#7FFF00',
\ 'chartreuse2': '#76EE00',
\ 'chartreuse3': '#66CD00',
\ 'chartreuse4': '#458B00',
\ 'olivedrab1': '#C0FF3E',
\ 'olivedrab2': '#B3EE3A',
\ 'olivedrab3': '#9ACD32',
\ 'olivedrab4': '#698B22',
\ 'darkolivegreen1': '#CAFF70',
\ 'darkolivegreen2': '#BCEE68',
\ 'darkolivegreen3': '#A2CD5A',
\ 'darkolivegreen4': '#6E8B3D',
\ 'khaki1': '#FFF68F',
\ 'khaki2': '#EEE685',
\ 'khaki3': '#CDC673',
\ 'khaki4': '#8B864E',
\ 'lightgoldenrod1': '#FFEC8B',
\ 'lightgoldenrod2': '#EEDC82',
\ 'lightgoldenrod3': '#CDBE70',
\ 'lightgoldenrod4': '#8B814C',
\ 'lightyellow1': '#FFFFE0',
\ 'lightyellow2': '#EEEED1',
\ 'lightyellow3': '#CDCDB4',
\ 'lightyellow4': '#8B8B7A',
\ 'yellow1': '#FFFF00',
\ 'yellow2': '#EEEE00',
\ 'yellow3': '#CDCD00',
\ 'yellow4': '#8B8B00',
\ 'gold1': '#FFD700',
\ 'gold2': '#EEC900',
\ 'gold3': '#CDAD00',
\ 'gold4': '#8B7500',
\ 'goldenrod1': '#FFC125',
\ 'goldenrod2': '#EEB422',
\ 'goldenrod3': '#CD9B1D',
\ 'goldenrod4': '#8B6914',
\ 'darkgoldenrod1': '#FFB90F',
\ 'darkgoldenrod2': '#EEAD0E',
\ 'darkgoldenrod3': '#CD950C',
\ 'darkgoldenrod4': '#8B6508',
\ 'rosybrown1': '#FFC1C1',
\ 'rosybrown2': '#EEB4B4',
\ 'rosybrown3': '#CD9B9B',
\ 'rosybrown4': '#8B6969',
\ 'indianred1': '#FF6A6A',
\ 'indianred2': '#EE6363',
\ 'indianred3': '#CD5555',
\ 'indianred4': '#8B3A3A',
\ 'sienna1': '#FF8247',
\ 'sienna2': '#EE7942',
\ 'sienna3': '#CD6839',
\ 'sienna4': '#8B4726',
\ 'burlywood1': '#FFD39B',
\ 'burlywood2': '#EEC591',
\ 'burlywood3': '#CDAA7D',
\ 'burlywood4': '#8B7355',
\ 'wheat1': '#FFE7BA',
\ 'wheat2': '#EED8AE',
\ 'wheat3': '#CDBA96',
\ 'wheat4': '#8B7E66',
\ 'tan1': '#FFA54F',
\ 'tan2': '#EE9A49',
\ 'tan3': '#CD853F',
\ 'tan4': '#8B5A2B',
\ 'chocolate1': '#FF7F24',
\ 'chocolate2': '#EE7621',
\ 'chocolate3': '#CD661D',
\ 'chocolate4': '#8B4513',
\ 'firebrick1': '#FF3030',
\ 'firebrick2': '#EE2C2C',
\ 'firebrick3': '#CD2626',
\ 'firebrick4': '#8B1A1A',
\ 'brown1': '#FF4040',
\ 'brown2': '#EE3B3B',
\ 'brown3': '#CD3333',
\ 'brown4': '#8B2323',
\ 'salmon1': '#FF8C69',
\ 'salmon2': '#EE8262',
\ 'salmon3': '#CD7054',
\ 'salmon4': '#8B4C39',
\ 'lightsalmon1': '#FFA07A',
\ 'lightsalmon2': '#EE9572',
\ 'lightsalmon3': '#CD8162',
\ 'lightsalmon4': '#8B5742',
\ 'orange1': '#FFA500',
\ 'orange2': '#EE9A00',
\ 'orange3': '#CD8500',
\ 'orange4': '#8B5A00',
\ 'darkorange1': '#FF7F00',
\ 'darkorange2': '#EE7600',
\ 'darkorange3': '#CD6600',
\ 'darkorange4': '#8B4500',
\ 'coral1': '#FF7256',
\ 'coral2': '#EE6A50',
\ 'coral3': '#CD5B45',
\ 'coral4': '#8B3E2F',
\ 'tomato1': '#FF6347',
\ 'tomato2': '#EE5C42',
\ 'tomato3': '#CD4F39',
\ 'tomato4': '#8B3626',
\ 'orangered1': '#FF4500',
\ 'orangered2': '#EE4000',
\ 'orangered3': '#CD3700',
\ 'orangered4': '#8B2500',
\ 'red1': '#FF0000',
\ 'red2': '#EE0000',
\ 'red3': '#CD0000',
\ 'red4': '#8B0000',
\ 'deeppink1': '#FF1493',
\ 'deeppink2': '#EE1289',
\ 'deeppink3': '#CD1076',
\ 'deeppink4': '#8B0A50',
\ 'hotpink1': '#FF6EB4',
\ 'hotpink2': '#EE6AA7',
\ 'hotpink3': '#CD6090',
\ 'hotpink4': '#8B3A62',
\ 'pink1': '#FFB5C5',
\ 'pink2': '#EEA9B8',
\ 'pink3': '#CD919E',
\ 'pink4': '#8B636C',
\ 'lightpink1': '#FFAEB9',
\ 'lightpink2': '#EEA2AD',
\ 'lightpink3': '#CD8C95',
\ 'lightpink4': '#8B5F65',
\ 'palevioletred1': '#FF82AB',
\ 'palevioletred2': '#EE799F',
\ 'palevioletred3': '#CD6889',
\ 'palevioletred4': '#8B475D',
\ 'maroon1': '#FF34B3',
\ 'maroon2': '#EE30A7',
\ 'maroon3': '#CD2990',
\ 'maroon4': '#8B1C62',
\ 'violetred1': '#FF3E96',
\ 'violetred2': '#EE3A8C',
\ 'violetred3': '#CD3278',
\ 'violetred4': '#8B2252',
\ 'magenta1': '#FF00FF',
\ 'magenta2': '#EE00EE',
\ 'magenta3': '#CD00CD',
\ 'magenta4': '#8B008B',
\ 'orchid1': '#FF83FA',
\ 'orchid2': '#EE7AE9',
\ 'orchid3': '#CD69C9',
\ 'orchid4': '#8B4789',
\ 'plum1': '#FFBBFF',
\ 'plum2': '#EEAEEE',
\ 'plum3': '#CD96CD',
\ 'plum4': '#8B668B',
\ 'mediumorchid1': '#E066FF',
\ 'mediumorchid2': '#D15FEE',
\ 'mediumorchid3': '#B452CD',
\ 'mediumorchid4': '#7A378B',
\ 'darkorchid1': '#BF3EFF',
\ 'darkorchid2': '#B23AEE',
\ 'darkorchid3': '#9A32CD',
\ 'darkorchid4': '#68228B',
\ 'purple1': '#9B30FF',
\ 'purple2': '#912CEE',
\ 'purple3': '#7D26CD',
\ 'purple4': '#551A8B',
\ 'mediumpurple1': '#AB82FF',
\ 'mediumpurple2': '#9F79EE',
\ 'mediumpurple3': '#8968CD',
\ 'mediumpurple4': '#5D478B',
\ 'thistle1': '#FFE1FF',
\ 'thistle2': '#EED2EE',
\ 'thistle3': '#CDB5CD',
\ 'thistle4': '#8B7B8B',
\ 'gray0': '#000000',
\ 'grey0': '#000000',
\ 'gray1': '#030303',
\ 'grey1': '#030303',
\ 'gray2': '#050505',
\ 'grey2': '#050505',
\ 'gray3': '#080808',
\ 'grey3': '#080808',
\ 'gray4': '#0A0A0A',
\ 'grey4': '#0A0A0A',
\ 'gray5': '#0D0D0D',
\ 'grey5': '#0D0D0D',
\ 'gray6': '#0F0F0F',
\ 'grey6': '#0F0F0F',
\ 'gray7': '#121212',
\ 'grey7': '#121212',
\ 'gray8': '#141414',
\ 'grey8': '#141414',
\ 'gray9': '#171717',
\ 'grey9': '#171717',
\ 'gray10': '#1A1A1A',
\ 'grey10': '#1A1A1A',
\ 'gray11': '#1C1C1C',
\ 'grey11': '#1C1C1C',
\ 'gray12': '#1F1F1F',
\ 'grey12': '#1F1F1F',
\ 'gray13': '#212121',
\ 'grey13': '#212121',
\ 'gray14': '#242424',
\ 'grey14': '#242424',
\ 'gray15': '#262626',
\ 'grey15': '#262626',
\ 'gray16': '#292929',
\ 'grey16': '#292929',
\ 'gray17': '#2B2B2B',
\ 'grey17': '#2B2B2B',
\ 'gray18': '#2E2E2E',
\ 'grey18': '#2E2E2E',
\ 'gray19': '#303030',
\ 'grey19': '#303030',
\ 'gray20': '#333333',
\ 'grey20': '#333333',
\ 'gray21': '#363636',
\ 'grey21': '#363636',
\ 'gray22': '#383838',
\ 'grey22': '#383838',
\ 'gray23': '#3B3B3B',
\ 'grey23': '#3B3B3B',
\ 'gray24': '#3D3D3D',
\ 'grey24': '#3D3D3D',
\ 'gray25': '#404040',
\ 'grey25': '#404040',
\ 'gray26': '#424242',
\ 'grey26': '#424242',
\ 'gray27': '#454545',
\ 'grey27': '#454545',
\ 'gray28': '#474747',
\ 'grey28': '#474747',
\ 'gray29': '#4A4A4A',
\ 'grey29': '#4A4A4A',
\ 'gray30': '#4D4D4D',
\ 'grey30': '#4D4D4D',
\ 'gray31': '#4F4F4F',
\ 'grey31': '#4F4F4F',
\ 'gray32': '#525252',
\ 'grey32': '#525252',
\ 'gray33': '#545454',
\ 'grey33': '#545454',
\ 'gray34': '#575757',
\ 'grey34': '#575757',
\ 'gray35': '#595959',
\ 'grey35': '#595959',
\ 'gray36': '#5C5C5C',
\ 'grey36': '#5C5C5C',
\ 'gray37': '#5E5E5E',
\ 'grey37': '#5E5E5E',
\ 'gray38': '#616161',
\ 'grey38': '#616161',
\ 'gray39': '#636363',
\ 'grey39': '#636363',
\ 'gray40': '#666666',
\ 'grey40': '#666666',
\ 'gray41': '#696969',
\ 'grey41': '#696969',
\ 'gray42': '#6B6B6B',
\ 'grey42': '#6B6B6B',
\ 'gray43': '#6E6E6E',
\ 'grey43': '#6E6E6E',
\ 'gray44': '#707070',
\ 'grey44': '#707070',
\ 'gray45': '#737373',
\ 'grey45': '#737373',
\ 'gray46': '#757575',
\ 'grey46': '#757575',
\ 'gray47': '#787878',
\ 'grey47': '#787878',
\ 'gray48': '#7A7A7A',
\ 'grey48': '#7A7A7A',
\ 'gray49': '#7D7D7D',
\ 'grey49': '#7D7D7D',
\ 'gray50': '#7F7F7F',
\ 'grey50': '#7F7F7F',
\ 'gray51': '#828282',
\ 'grey51': '#828282',
\ 'gray52': '#858585',
\ 'grey52': '#858585',
\ 'gray53': '#878787',
\ 'grey53': '#878787',
\ 'gray54': '#8A8A8A',
\ 'grey54': '#8A8A8A',
\ 'gray55': '#8C8C8C',
\ 'grey55': '#8C8C8C',
\ 'gray56': '#8F8F8F',
\ 'grey56': '#8F8F8F',
\ 'gray57': '#919191',
\ 'grey57': '#919191',
\ 'gray58': '#949494',
\ 'grey58': '#949494',
\ 'gray59': '#969696',
\ 'grey59': '#969696',
\ 'gray60': '#999999',
\ 'grey60': '#999999',
\ 'gray61': '#9C9C9C',
\ 'grey61': '#9C9C9C',
\ 'gray62': '#9E9E9E',
\ 'grey62': '#9E9E9E',
\ 'gray63': '#A1A1A1',
\ 'grey63': '#A1A1A1',
\ 'gray64': '#A3A3A3',
\ 'grey64': '#A3A3A3',
\ 'gray65': '#A6A6A6',
\ 'grey65': '#A6A6A6',
\ 'gray66': '#A8A8A8',
\ 'grey66': '#A8A8A8',
\ 'gray67': '#ABABAB',
\ 'grey67': '#ABABAB',
\ 'gray68': '#ADADAD',
\ 'grey68': '#ADADAD',
\ 'gray69': '#B0B0B0',
\ 'grey69': '#B0B0B0',
\ 'gray70': '#B3B3B3',
\ 'grey70': '#B3B3B3',
\ 'gray71': '#B5B5B5',
\ 'grey71': '#B5B5B5',
\ 'gray72': '#B8B8B8',
\ 'grey72': '#B8B8B8',
\ 'gray73': '#BABABA',
\ 'grey73': '#BABABA',
\ 'gray74': '#BDBDBD',
\ 'grey74': '#BDBDBD',
\ 'gray75': '#BFBFBF',
\ 'grey75': '#BFBFBF',
\ 'gray76': '#C2C2C2',
\ 'grey76': '#C2C2C2',
\ 'gray77': '#C4C4C4',
\ 'grey77': '#C4C4C4',
\ 'gray78': '#C7C7C7',
\ 'grey78': '#C7C7C7',
\ 'gray79': '#C9C9C9',
\ 'grey79': '#C9C9C9',
\ 'gray80': '#CCCCCC',
\ 'grey80': '#CCCCCC',
\ 'gray81': '#CFCFCF',
\ 'grey81': '#CFCFCF',
\ 'gray82': '#D1D1D1',
\ 'grey82': '#D1D1D1',
\ 'gray83': '#D4D4D4',
\ 'grey83': '#D4D4D4',
\ 'gray84': '#D6D6D6',
\ 'grey84': '#D6D6D6',
\ 'gray85': '#D9D9D9',
\ 'grey85': '#D9D9D9',
\ 'gray86': '#DBDBDB',
\ 'grey86': '#DBDBDB',
\ 'gray87': '#DEDEDE',
\ 'grey87': '#DEDEDE',
\ 'gray88': '#E0E0E0',
\ 'grey88': '#E0E0E0',
\ 'gray89': '#E3E3E3',
\ 'grey89': '#E3E3E3',
\ 'gray90': '#E5E5E5',
\ 'grey90': '#E5E5E5',
\ 'gray91': '#E8E8E8',
\ 'grey91': '#E8E8E8',
\ 'gray92': '#EBEBEB',
\ 'grey92': '#EBEBEB',
\ 'gray93': '#EDEDED',
\ 'grey93': '#EDEDED',
\ 'gray94': '#F0F0F0',
\ 'grey94': '#F0F0F0',
\ 'gray95': '#F2F2F2',
\ 'grey95': '#F2F2F2',
\ 'gray96': '#F5F5F5',
\ 'grey96': '#F5F5F5',
\ 'gray97': '#F7F7F7',
\ 'grey97': '#F7F7F7',
\ 'gray98': '#FAFAFA',
\ 'grey98': '#FAFAFA',
\ 'gray99': '#FCFCFC',
\ 'grey99': '#FCFCFC',
\ 'gray100': '#FFFFFF',
\ 'grey100': '#FFFFFF',
\ 'darkgrey': '#A9A9A9',
\ 'darkgray': '#A9A9A9',
\ 'darkblue': '#00008B',
\ 'darkcyan': '#008B8B',
\ 'darkmagenta': '#8B008B',
\ 'darkred': '#8B0000',
\ 'lightgreen': '#90EE90'
\ }

" Functions, to highlight certain types {{{1
function! s:ColorRGBValues(val) "{{{2
    let s:position = getpos('.')
    if <sid>IsInComment()
        " skip coloring comments
        return
    endif
    " strip parantheses and split on comma
    let rgb = s:StripParentheses(a:val)
    if empty(rgb)
        call s:Warn("Error in expression". a:val. "! Please report as bug.")
        return
    endif
    for i in range(3)
        if rgb[i][-1:-1] == '%'
            let val = matchstr(rgb[i], '\d\+')
            if (val + 0 > 100)
                let rgb[1] = 100
            endif
            let rgb[i] = float2nr((val + 0.0)*255/100)
        else
            if rgb[i] + 0 > 255
                let rgb[i] = 255
            endif
        endif
    endfor
    if len(rgb) == 4
        let rgb = s:ApplyAlphaValue(rgb)
    endif
    let clr = printf("%02X%02X%02X", rgb[0],rgb[1],rgb[2])
    call s:SetMatcher(a:val, {'bg': clr})
    if s:use_virtual_text
      return a:val
    endif
endfunction

function! s:ColorHSLValues(val) "{{{2
    let s:position = getpos('.')
    if <sid>IsInComment()
        " skip coloring comments
        return
    endif
    " strip parantheses and split on comma
    let hsl = s:StripParentheses(a:val)
    if empty(hsl)
        call s:Warn("Error in expression". a:val. "! Please report as bug.")
        return
    endif
    let str = s:PrepareHSLArgs(hsl)

    call s:SetMatcher(a:val, {'bg': str})
    if s:use_virtual_text
      return a:val
    endif
endfu

function! s:PreviewColorName(color) "{{{2
    let s:position = getpos('.')
    let name=tolower(a:color)
    let clr = s:colors[name]
    " Skip color-name, e.g. white-space property
    call s:SetMatcher('-\@<!\<'.name.'\>\c-\@!', {'bg': clr[1:]})
    if s:use_virtual_text
      return a:color
    endif
endfu

function! s:PreviewColorHex(match) "{{{2
    let s:position = getpos('.')
    if <sid>IsInComment()
        " skip coloring comments
        return
    endif
    " Make sure the pattern matches the complete string, so anchor it
    " explicitly at the end (see #64)
    let color = matchstr(a:match, s:hex_pattern[1]."$")
    let pattern = color
    if len(color) == 3
        let color = substitute(color, '.', '&&', 'g')
    endif
    if &t_Co == 8 && !s:HasGui()
        " The first 12 color names, can be displayed by 8 color terminals
        let list = values(s:xterm_8colors)
        let idx = match(list, a:match)
        if idx == -1
            " Color can't be displayed by 8 color terminal
            return
        else
            let color = list[idx]
        endif
    endif
    if len(split(pattern, '\zs')) == 8
        " apply alpha value
        let l = split(pattern, '..\zs')
        call map(l, 'printf("%2d", "0x".v:val)')
        let l[3] = string(str2float(l[3])/255)  " normalize to 0-1
        let l = s:ApplyAlphaValue(l)
        let color = printf("%02X%02X%02X", l[0], l[1], l[2])
    endif
    call s:SetMatcher(s:hex_pattern[0]. pattern. s:hex_pattern[2], {'bg': color})
    if s:use_virtual_text
      return a:match
    endif
endfunction

function! s:PreviewColorTerm(pre, text, post) "{{{2
    " a:pre: Ansi-Sequences determining the highlighting
    " a:text: Text to color
    " a:post: Ansi-Sequences resetting the coloring (might be empty)
    let s:position = getpos('.')
    let color = s:Ansi2Color(a:pre)
    let clr_Dict = {}

    if &t_Co == 8 && !s:HasGui()
        " The first 12 color names, can be displayed by 8 color terminals
        let i = 0
        for clr in color
            let list = values(s:xterm_8colors)
            let idx = match(list, clr)
            if idx == -1
                " Color can't be displayed by 8 color terminal
                let color[i] = NONE
            else
                let color[i] = list[idx]
            endif
            let i+=1
        endfor
    endif
    let clr_Dict.fg = color[0]
    let clr_Dict.bg = color[1]
    let pre  = escape(a:pre,  '[]')
    let post = escape(a:post, '[]')
    let txt  = escape(a:text, '\^$.*~[]')
    " limit the pattern to the belonging line (should make syntax matching
    " faster!)
    let pattern = '\%(\%'.line('.').'l\)\%('. pre. '\)\@<='.txt. '\('.post.'\)\@='
    " needs matchaddpos
    let clr_Dict.pos = [[ line('.'), col('.'), strlen(a:pre. a:text. a:post)]]
    call s:SetMatcher(pattern, clr_Dict)
    if s:use_virtual_text
      return a:pre . a:text. a:post
    endif
endfunction
function! s:PreviewColorTermBold(pre, txt, post) "{{{2
    " a:pre: Ansi-Sequences determining the highlighting
    " a:text: Text to color
    " a:post: Ansi-Sequences resetting the coloring (might be empty)
    let s:position = getpos('.')
    let fg = synIDattr(synID(line("."), col("."), 1), "fg")
    let bg = synIDattr(synID(line("."), col("."), 1), "bg")
    " Fall-back to Normal
    if empty(fg)
      let fg = synIDattr(hlID('Normal'), 'fg')
    endif
    if empty(bg)
      let bg = synIDattr(hlID('Normal'), 'bg')
    endif
    let clr_Dict = {'fg': fg, 'bg': bg, 'special': 'bold'}
    " limit the pattern to the belonging line (should make syntax matching
    " faster!)
    let pattern = '\%(\%'.line('.').'l\)\%(\V'. a:pre. '\m\)\@<=\(\V'.a:txt. '\m\)\(\V'.a:post.'\m\)\@='
    call s:SetMatcher(pattern, clr_Dict)
    if s:use_virtual_text
      return a:pre . a:txt. a:post
    endif
endfunction
function! s:PreviewColorNroff(match) "{{{2
    let s:position = getpos('.')
    let clr_Dict = {}
    let color = []
    if a:match[0] == '_'
      let special = 'underline'
    else
      let special = 'bold'
    endif
    let synid=synIDtrans(synID(line('.'), col('.'), 1))
    if synid == 0
      let synid = hlID('Normal')
    endif
    let color=[synIDattr(synid, 'fg'), synIDattr(synid, 'bg')]
    if color == [0, 0] || color == ['', '']
      let color = [synIDattr(hlID('Normal'), 'fg'), synIDattr(hlID('Normal'), 'bg')]
    endif

    let clr_Dict.fg = color[0]
    let clr_Dict.bg = color[1]
    let clr_Dict.special=special
    " limit the pattern to the belonging line (should make syntax matching
    " faster!)
    let pattern = '\%(\%'.line('.').'l\)'.a:match
    " needs matchaddpos
    let clr_Dict.pos = [[ line('.'), col('.'), 3]]
    call s:SetMatcher(pattern, clr_Dict)
    if s:use_virtual_text
      return a:match
    endif
endfunction
function! s:PreviewTaskWarriorColors(submatch) "{{{2
    " a:submatch is something like 'black on rgb141'

    " this highlighting should overrule e.g. colorname highlighting
    let s:position = getpos('.')
    let s:default_match_priority += 1
    let color = ['', 'NONE', 'NONE']
    let color_Dict = {}
    " The submatch is everything after the first equalsign!
    let tpat = '\(inverse\|underline\|bright\|bold\)\?\%(\s*\)\(\S\{3,}\)'.
                \ '\?\%(\s*\)\?\%(on\s\+'.
                \ '\%(inverse\|underline\|bright\|bold\)\?\%(\s*\)\(\S\{3,}\)\)\?'
    let colormatch = matchlist(a:submatch, tpat)
    try
        if !empty(colormatch) && !empty(colormatch[0])
            let i=-1
            for m in colormatch[1:3]
                let i+=1
                if i == 0
                    if (!empty(colormatch[1]))
                        let color_Dict.special=colormatch[1]
                    else
                        continue
                    endif
                endif
                if match(keys(s:colors), '\<'.m.'\>') > -1
                    if i == 1
                        let color_Dict.fg = s:colors[m][1:] " skip the # sign
                    elseif i == 2
                        let color_Dict.bg = s:colors[m][1:] " skip the # sign
                    endif
                    continue
                elseif match(m, '^rgb...') > -1
                    let color[i] = m[3] * 36 + m[4] * 6 + m[5] + 16 " (start at index 16)
                    if color[i] > 231
                        " invalid color
                        return
                    endif
                elseif match(m, '^color') > -1
                    let color[i] = matchstr(m, '\d\+')+0
                    if color[i] > 231
                        " invalid color
                        return
                    endif
                elseif match(m, '^gray') > -1
                    let color[i] = matchstr(m, '\d\+') + 232
                    if color[i] > 231
                        " invalid color
                        return
                    endif
                endif
                if i == 1
                    let color_Dict.ctermfg = color[i]
                elseif i == 2
                    let color_Dict.ctermbg = color[i]
                endif
            endfor

            let cname = get(color_Dict, 'fg', 'NONE')
            if cname ==# 'NONE' && get(color_Dict, 'ctermfg')
                let cname = s:Term2RGB(color_Dict.ctermfg)
            endif
            call s:SetMatcher('=\s*\zs\<'.a:submatch.'\>$', color_Dict)
            if s:use_virtual_text
              return a:submatch
            endif
        endif
    finally
        let s:default_match_priority -= 1
        let s:stop = 1
    endtry
endfunction

function! s:PreviewVimColors(submatch) "{{{2
    " a:submatch is something like 'black on rgb141'

    " this highlighting should overrule e.g. colorname highlighting
    let s:position = getpos('.')
    let s:default_match_priority += 1
    if !exists("s:x11_color_pattern")
        let s:x11_color_pattern =  s:GetColorPattern(keys(s:x11_color_names))
    endif
    let color_Dict = {}
    let pat1 = '\%(\(cterm[fb]g\)\s*=\s*\)\@<=\<\(\d\+\)\>'
    let pat2 = '\%(\(gui[fb]g\)\s*=\s*\)\@<=#\(\x\{6}\)\>'
    let x11_color_pattern = s:x11_color_pattern
    if (s:x11_color_pattern[0:3] == '\%#=')
      " Skip regexp engine
      let x11_color_pattern = x11_color_pattern[5:]
    endif
    let pat3 = '\%#=1\%(\%(\(gui[fb]g\)\s*=\s*\)\@<=\('.x11_color_pattern.'\)\)'

    let cterm = matchlist(a:submatch, pat1)
    let gui   = matchlist(a:submatch, pat2)
    if (!empty(gui) && (gui[2] ==# 'bg' ||
      \ gui[2] ==# 'fg' ||
      \ gui[2] ==# 'foreground' ||
      \ gui[2] ==# 'background'))
        let gui=[]
    endif
    if  empty(gui)
        let gui   = matchlist(a:submatch, pat3)
        if !empty(gui)
            let gui[2] = s:x11_color_names[tolower(gui[2])]
        endif
    endif
    try
        if !empty(cterm)
            let color_Dict.ctermbg = cterm[2]
        elseif !empty(gui)
            let color_Dict.bg = gui[2]
        endif

        if empty(gui) && empty(cterm)
            return
        endif

        call s:SetMatcher('\<'.a:submatch.'\>', color_Dict)
        if s:use_virtual_text
          return a:submatch
        endif
    finally
        let s:default_match_priority -= 1
    endtry
endfunction

function! s:PreviewVimHighlightDump(match) "{{{2
    " highlights dumps of :hi
    " e.g
    "SpecialKey     xxx term=bold cterm=bold ctermfg=124 guifg=Cyan
    let s:position = getpos('.')
    let s:default_match_priority += 1
    let dict = {}
    try
        let match = split(a:match, '\_s\+')
        if a:match =~# 'cleared'
            " ipaddr         xxx cleared
            return
        elseif a:match =~# 'links to'
            " try to find a non-cleared group
            let c1 =  <sid>SynID(match[0])
            let group = match[0]
            if empty(c1)
                let group = match[-1]
            endif
            call s:SetMatch('Color_'.group, '^'.s:GetPatternLiteral(a:match), {})
        else
            let dict.name = 'Color_'.match[0]
            call remove(match, 0, 1)
            let dict = s:DictFromList(dict, match)
            call s:SetMatcher(s:GetPatternLiteral(a:match), dict)
            if s:use_virtual_text
              return a:match
            endif
        endif
    finally
        let s:default_match_priority -= 1
        " other highlighting functions shouldn't run anymore
        let s:stop = 1
    endtry
endfunction

function! s:PreviewVimHighlight(match) "{{{2
    " like colorhighlight plugin,
    " colorizer highlight statements in .vim files
    let s:position = getpos('.')
    let tmatch = a:match
    let def    = []
    let dict   = {}
    try
        if a:match =~ '^\s*hi\%[ghlight]\s\+clear'
            " highlight clear lines, don't colorize!
            return
        endif
        " Special case:
        " HtmlHiLink foo bar -> links foo to bar
        " hi! def link foo bar -> links foo to bar
        let match = matchlist(tmatch, '\C\%(\%[Html\]HiLink\|hi\%[ghlight]!\?\s*\%(def\%[ault]\s*\)\?link\)\s\+\(\w\+\)\s\+\(\w\+\)')
        " Hopefully tmatch[1] has already been defined ;(
        if len(match)
            call s:SetMatch('Color_'.match[1], '^\V'.escape(a:match, '\\'), {})
            return
        endif
        let tmatch = substitute(tmatch, '^\c\s*hi\%[ghlight]!\?\(\s*def\%[ault]\)\?', '', '')
        let match = map(split(tmatch), 'substitute(v:val, ''^\s\+\|\s\+$'', "", "g")')
        if len(match) < 2
            return
        else
            let dict.name = 'Color_'.get(match, 0)
            let dict = s:DictFromList(dict, match)
            call s:SetMatcher(s:GetPatternLiteral(a:match), dict)
            if s:use_virtual_text
              return a:match
            endif
        endif
    endtry
endfunction

function! s:IsInComment() "{{{1
    return s:skip_comments &&
        \ synIDattr(synIDtrans(synID(line('.'), col('.'),1)), 'name') == "Comment"
endfu

function! s:DictFromList(dict, list) "{{{1
    let dict = copy(a:dict)
    let match = filter(a:list, 'v:val =~# ''=''')
    for item in match
        let [t1, t2] = split(item, '=')
        let dict[t1] = t2
    endfor
    return dict
endfunction

function! s:GetPatternLiteral(pat) "{{{1
    return '\V'. substitute(escape(a:pat, '\\'), "\n", '\\n', 'g')
endfu
function! s:Term2RGB(index) "{{{1
    if !exists("s:colortable")
        call s:ColortableInit()
    endif
    " Return index in colortable in RRGGBB form
    return join(map(copy(s:colortable[a:index]), 'printf("%02X", v:val)'),'')
endfu

function! s:Reltime(...) "{{{1
    return exists("a:1") ? reltime(a:1) : reltime()
endfu

function! s:PrintColorStatistics() "{{{1
    if get(g:, 'colorizer_debug', 0)
        echohl Title
        echom printf("Colorstatistics at: %s", strftime("%H:%M"))
        echom printf("Duration: %s", reltimestr(s:relstop))
        for name in sort(keys(extend(s:color_patterns, s:color_patterns_special)))
            let value = get(extend(s:color_patterns, s:color_patterns_special), name)
            echom printf("%15s: %ss", name, (value[-1] == [] ? '  0.000000' : reltimestr(value[-1])))
        endfor
        echohl Normal
    endif
endfu

function! s:ColortableInit() "{{{1
    " Only calculate the colortable when running
    if &t_Co == 8
        let s:colortable = map(range(0, 7), 's:Xterm2rgb16(v:val)')
    elseif &t_Co == 16
        let s:colortable = map(range(0, 15), 's:Xterm2rgb16(v:val)')
    elseif &t_Co == 88
        let s:colortable = map(range(0, 87), 's:Xterm2rgb88(v:val)')
    " terminal with 256 colors or gVim
    "elseif &t_Co == 256 || empty(&t_Co) || &t_Co == 16777216
    else
        let s:colortable = map(range(0, 255), 's:Xterm2rgb256(v:val)')
    endif
    if s:debug && exists("s:colortable")
        let g:colortable = s:colortable
    endif
endfu

function! s:ColorInit(...) "{{{1
    let s:force_hl = !empty(a:1)
    let s:term_true_color = (exists('+tgc') && &tgc)
    let s:stop = 0
    let s:use_virtual_text = has("nvim") && get(g:, 'colorizer_use_virtual_text', 0)

    " default matchadd priority
    let s:default_match_priority = -2

    " pattern/function dict
    " Needed for s:ColorMatchingLines(), disabled, as this is too slow.
    "let s:pat_func = {'#\x\{3,6\}': function('<sid>PreviewColorHex'),
    "            \ 'rgba\=(\s*\%(\d\+%\?\D*\)\{3,4})':
    "            \ function('<sid>ColorRGBValues'),
    "            \ 'hsla\=(\s*\%(\d\+%\?\D*\)\{3,4})':
    "            \ function('s:ColorHSLValues')}

    " Cache old values
    if !exists("s:old_tCo")
        let s:old_tCo = &t_Co
    endif

    if !exists("s:swap_fg_bg")
        let s:swap_fg_bg = 0
    endif

    if !exists("s:round")
        let s:round = 0
    endif

    " Enable Autocommands
    if exists("g:colorizer_auto_color")
        call Colorizer#AutoCmds(g:colorizer_auto_color)
    endif

    " disable terminal coloring for all filetypes except text files
    " it's too expensive and probably does not make sense to enable it for
    " other filetypes
    let s:colorizer_term_disable = !(empty(&filetype) || &filetype == 'text')
    let s:colorizer_nroff_disable = !(empty(&filetype) || &filetype == 'text')

    " Debugging
    let s:debug = get(g:, 'colorizer_debug', 0)

    " Don't highlight comment?
    let s:skip_comments = get(g:, 'colorizer_skip_comments', 0)

    " foreground / background contrast
    let s:predefined_fgcolors = {}
    let s:predefined_fgcolors['dark']  = ['444444', '222222', '000000']
    let s:predefined_fgcolors['light'] = ['bbbbbb', 'dddddd', 'ffffff']
    if !exists('g:colorizer_fgcontrast')
        " Default to black / white
        let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
    elseif g:colorizer_fgcontrast >= len(s:predefined_fgcolors['dark'])
        call s:Warn("g:colorizer_fgcontrast value invalid, using default")
        let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
    endif

    if !exists("s:old_fgcontrast")
        " if the value was changed since last time,
        " be sure to clear the old highlighting.
        let s:old_fgcontrast = g:colorizer_fgcontrast
    endif

    if exists("g:colorizer_swap_fgbg")
        if s:swap_fg_bg != g:colorizer_swap_fgbg
            let s:force_hl = 1
        endif
        let s:swap_fg_bg = g:colorizer_swap_fgbg
    endif

    if exists("g:colorizer_colornames")
        if exists("s:color_names") &&
        \ s:color_names != g:colorizer_colornames
            let s:force_hl = 1
        endif
        let s:color_names = g:colorizer_colornames
    else
        let s:color_names = 1
    endif

    let s:color_syntax = get(g:, 'colorizer_syntax', 0)
    if get(g:, 'colorizer_only_unfolded', 0) && exists(":foldd") == 1
        let s:color_unfolded = 'foldd '
    else
        let s:color_unfolded = ''
    endif

    if hlID('Color_Error') == 0
        hi default link Color_Error Error
    endif

    if !s:force_hl && s:old_fgcontrast != g:colorizer_fgcontrast
                \ && s:swap_fg_bg == 0
        " Doesn't work with swapping fg bg colors
        let s:force_hl = 1
        let s:old_fgcontrast = g:colorizer_fgcontrast
    endif

    " User manually changed the &t_Co option, so reset it
    if s:old_tCo != &t_Co
        unlet! s:colortable
    endif

    if !exists("s:init_css") || !exists("s:colortable") || empty(s:colortable)
        call s:ColortableInit()
        let s:init_css = 1
    elseif s:force_hl
        call Colorizer#ColorOff()
    endif
    let s:conceal = [&l:cole, &l:cocu]

    let s:hex_pattern = get(g:, 'colorizer_hex_pattern',
                \ ['#', '\%(\x\{3}\|\x\{6}\|\x\{8\}\)', '\%(\>\|[-_]\)\@='])

    if s:HasGui() || &t_Co >= 8 || s:HasColorPattern()
        " The list of available match() patterns
        let w:match_list = s:GetMatchList()
        " If the syntax highlighting got reset, force recreating it
        if ((empty(w:match_list) || !hlexists(w:match_list[0].group) ||
            \ (empty(<sid>SynID(w:match_list[0].group)) && !s:force_hl)))
            let s:force_hl = 1
        endif
        if &t_Co > 16 || s:HasGui()
            let s:colors = (exists("g:colorizer_x11_names") ?
                \ s:x11_color_names : s:w3c_color_names)
        elseif &t_Co == 16
            " should work with 16 colors terminals
            let s:colors = s:xterm_16colors
        else
            let s:colors = s:xterm_8colors
        endif
        if exists("g:colorizer_custom_colors")
            call extend(s:colors, g:colorizer_custom_colors, 'force')
        endif
        let s:colornamepattern =  s:GetColorPattern(keys(s:colors))
        "call map(w:match_list, 'v:val.pattern')
    else
        throw "nocolor"
    endif

    " Dictionary, containing all information on what to color
    " Key: Name
    " Value: List, containing 1) Pattern to find color
    "                         2) func ref to call on the match of 1
    "                         3) Name of variable, to enable or this enty
    "                         4) condition, that must be fullfilled, before
    "                            using this entry
    "                       ´ 5) reltime for dumping statistics
    let s:color_patterns = {
        \ 'rgb': ['rgb(\s*\%(\d\+%\?[^)]*\)\{3})',
            \ function("s:ColorRGBValues"), 'colorizer_rgb', 1, [] ],
        \ 'rgba': ['rgba(\s*\%(\d\+%\?\D*\)\{3}\%(\%(0\?\%(.\d\+\)\?\)\|1\))',
            \ function("s:ColorRGBValues"), 'colorizer_rgba', 1, [] ],
        \ 'hsla': ['hsla\=(\s*\%(\d\+%\?\D*\)\{3}\%(\%(0\?\%(.\d\+\)\?\)\|1\)\=)',
            \ function("s:ColorHSLValues"), 'colorizer_hsla', 1, [] ],
        \ 'vimcolors':  ['\%(gui[fb]g\|cterm[fb]g\)\s*=\s*\<\%(\d\+\|#\x\{6}\|\w\+\)\>',
            \ function("s:PreviewVimColors"), 'colorizer_vimcolors', '&ft ==# "vim"', [] ],
        \ 'vimhighlight': ['^\s*\%(\%[Html]HiLink\s\+\w\+\s\+\w\+\)\|'.
            \ '\(^\s*hi\%[ghlight]!\?\s\+\(clear\)\@!\S\+.*\)',
            \ function("s:PreviewVimHighlight"), 'colorizer_vimhighlight', '&ft ==# "vim"', [] ],
        \ 'taskwarrior':  ['^color[^=]*=\zs.\+$',
            \ function("s:PreviewTaskWarriorColors"), 'colorizer_taskwarrior', 'expand("%:e") ==# "theme"', [] ],
        \ 'hex': [join(s:hex_pattern, ''), function("s:PreviewColorHex"), 'colorizer_hex', 1, [] ],
        \ 'vimhighl_dump': ['^\v\w+\s+<xxx>%((\s+(term|cterm%([bf]g)?|gui%(%([bf]g|sp))?)\='.
            \ '[#0-9A-Za-z_,]+)+)?%(\_\s+links to \w+)?%( cleared)@!$',
            \ function("s:PreviewVimHighlightDump"), 'colorizer_vimhighl_dump', 'empty(&ft)', [] ]
        \ }

    " term_conceal: patterns to hide, currently: [K$ and the color patterns [0m[01;32m
    let s:color_patterns_special = {
        \ 'term_bold': [ '\(\%x1b\[1m\)\(.*\)\(\%x1b\[0m\)', function("s:PreviewColorTermBold"), 'colorizer_term_bold', [] ],
        \ 'term': [ '\%(\%(\%x1b\|\\033\)\[0m\)\?\(\%(\%(\%x1b\|\\033\)\[\d\+\%([:;]\d\+\)*m\)\+\)\([^\e]*\)\(\%(\%x1b\|\\033\)\%(\[0m\|\[K\)\)\=',
            \ function("s:PreviewColorTerm"), 'colorizer_term', [] ],
        \ 'term_nroff': ['\%(\(.\)\%u8\1\)\|\%(_\%u8.\)', function("s:PreviewColorNroff"), 'colorizer_nroff', [] ],
        \ 'term_conceal': [ ['\%(\(\%(\%x1b\[0m\)\?\%x1b\[[01-9]\+\%([;:]\d\+\)*\a\)\|\%x1b\[K$\)',
          \ '\%d13', '\%(\%x1b\[K\)', '\%(\%x1b\]\d\+;\d\+;\)', '\%(\%x1b\\\)',
          \ '\%x1b(B\%x1b\[m', '\%x1b\[m\%(\%x0f\)\?', '_\%u8.\@=', '\(.\)\%u8\%(\1\)\@=', '\%x1b\[3\?[0-1]m'],
          \ '',
          \ 'colorizer_term_conceal', [] ]
        \ }

    if exists("s:colornamepattern") && s:color_names
        let s:color_patterns["colornames"] = [ s:colornamepattern,
            \ function("s:PreviewColorName"), 'colorizer_colornames', 1, [] ]
    endif
endfu

function! s:ColorHighlight_1(force, line1, line2) "{{{1
  let s_flags = s:use_virtual_text ? 'egi' : 'egin'
  if &t_Co > 16 || s:HasGui()
    for Pat in values(s:color_patterns)
      let start = s:Reltime()
      if !get(g:, Pat[2], 1) || (get(g:, Pat[2]. '_disable', 0) > 0)
        let Pat[4] = s:Reltime(start)
        " Coloring disabled
        continue
      endif

      " 4th element in pattern is condition, that must be fullfilled,
      " before we continue
      if !empty(Pat[3]) && !eval(Pat[3])
        let Pat[4] = s:Reltime(start)
        continue
      endif

      " Check, the pattern isn't too costly...
      if s:CheckTimeout(Pat[0], a:force) && !s:IsInComment()
        let cmd = printf(':sil keeppatterns %d,%d%ss/%s/\=call(Pat[1], [submatch(0)])/'. s_flags,
              \ a:line1, a:line2, s:color_unfolded, Pat[0])
        try
          if Pat[2] ==# 'colorizer_vimhighlight' && !empty(bufname(''))
            " try to load the corresponding syntax file so the syntax
            " groups will be defined
            let s:extension = fnamemodify(expand('%'), ':t:r')
            let s:old_syntax = exists("b:current_syntax") ? b:current_syntax : ''
            call s:LoadSyntax(s:extension)
          endif

          exe cmd
          let Pat[4] = s:Reltime(start)
          if s:stop
              break
          endif
        catch
          " some error occurred, stop when finished (and don't setup auto
          " comands
          let s:error.=" Colorize: ". string(Pat)
          break
        finally
          if exists("s:extension")
            call s:LoadSyntax(&ft)
            unlet! s:extension
          endif
        endtry
      endif
    endfor
  else
    call s:Warn('Color configuration seems wrong, skipping colorization! Check t_Co setting!')
  endif
endfunc

function! s:ColorHighlight_2(force, line1, line2) "{{{1
  let s_flags = s:use_virtual_text ? 'egi' : 'egin'
  for Pat in [ s:color_patterns_special.term,
      \ s:color_patterns_special.term_nroff,
      \ s:color_patterns_special.term_bold ]
    " When force is not given, check if it is disabled
    if empty(a:force) && (!get(g:, Pat[2], 1) || (get(g:, Pat[2]. '_disable', 0) > 0))
      " Coloring disabled, skip
      continue
    endif
    let start = s:Reltime()
    if (s:CheckTimeout(Pat[0], a:force)) && !s:IsInComment()
      if Pat[2] is# 'colorizer_nroff'
        let arg = '[submatch(0)]'
      else
        let arg = '[submatch(1), submatch(2), submatch(3)]'
      endif
      let cmd = printf(':sil keeppatterns %d,%d%ss/%s/\=call(Pat[1],%s)/'. s_flags,
        \ a:line1, a:line2,  s:color_unfolded, Pat[0], arg)
      try
        exe cmd
        let Pat[3] = s:Reltime(start)
        " Hide ESC Terminal Chars
        let start = s:Reltime()
        call s:TermConceal(s:color_patterns_special.term_conceal[0])
        let s:color_patterns_special.term_conceal[3] = s:Reltime(start)
      catch
        " some error occurred, stop when finished (and don't setup auto
        " comands
        let s:error=" ColorTerm "
        break
      endtry
    endif
  endfor
endfu

function! s:SwapColors(list) "{{{1
  if empty(a:list[0]) && empty(a:list[1])
    return a:list
  elseif s:swap_fg_bg > 0
    return [a:list[1]] + ['NONE']
  elseif s:swap_fg_bg == -1
    return [a:list[1], a:list[0]]
  else
    return a:list
  endif
endfu

function! s:FGforBG(bg) "{{{1
   " takes a 6hex color code and returns a matching color that is visible
   let fgc = g:colorizer_fgcontrast
   if fgc == -1
       return a:bg
   endif
   if a:bg ==# 'NONE'
       return (&bg==#'dark' ? s:predefined_fgcolors['dark'][fgc] : s:predefined_fgcolors['light'][fgc])
   endif
   let r = '0x'.a:bg[0:1]+0
   let g = '0x'.a:bg[2:3]+0
   let b = '0x'.a:bg[4:5]+0
   if r*30 + g*59 + b*11 > 12000
        return s:predefined_fgcolors['dark'][fgc]
    else
        return s:predefined_fgcolors['light'][fgc]
   end
endfunction

function! s:DidColor(clr, pat) "{{{1
    let idx = index(w:match_list, a:pat)
    if idx > -1
        let attr = <sid>SynID(a:clr)
        if (!empty(attr) && get(w:match_list, idx) ==# a:pat)
            return 1
        endif
    endif
    return 0
endfu

function! s:DoHlGroup(group, Dict) "{{{1
    if !s:force_hl
        let syn = <sid>SynID(a:group)
        if !empty(syn)
            " highlighting already exists
            return
        endif
    endif

    if empty(a:Dict)
        " try to link the given highlight group
        call s:Exe("hi link ". a:group. " ". matchstr(a:group, 'Color_\zs.*'))
        return
    endif

    let hi = printf('hi %s ', a:group)
    let fg = get(a:Dict, 'fg', '')
    let bg = get(a:Dict, 'bg', '')
    let [fg, bg] = s:SwapColors([fg, bg])

    if !empty(fg) && fg[0] !=# '#' && fg !=# 'NONE'
        let fg='#'.fg
    endif
    if !empty(bg) && bg[0] !=# '#' && bg !=# 'NONE'
        let bg='#'.bg
    endif
    let hi .= printf('guifg=%s', fg)
    if has_key(a:Dict, "gui")
        let hi.=printf(" gui=%s ", a:Dict['gui'])
    endif
    if has_key(a:Dict, "guifg")
        let hi.=printf(" guifg=%s ", a:Dict['guifg'])
    endif
    let hi .= printf(' guibg=%s', bg)
    let special = get(a:Dict, 'special', '')
    if !empty(special)
      let hi .= printf(' gui=%s cterm=%s term=%s', special, special, special)
    endif

    if !s:HasGui()
        let fg = get(a:Dict, 'ctermfg', '')
        let bg = get(a:Dict, 'ctermbg', '')
        let [fg, bg] = s:SwapColors([fg, bg])
        if !empty(bg) || bg == 0
            let hi.= printf(' ctermbg=%s', bg)
        endif
        if !empty(fg) || fg == 0
            let hi.= printf(' ctermfg=%s', fg)
        endif
        if has_key(a:Dict, "term")
            let hi.=printf(" term=%s ", a:Dict['term'])
        endif
        if has_key(a:Dict, "cterm")
            let hi.=printf(" cterm=%s ", a:Dict['cterm'])
        endif
    endif
    call s:Exe(hi)
endfunction

function! s:Exe(stmt) "{{{1
    "Don't error out for invalid colors
    try
        exe a:stmt
    catch
        " Only report errors, when debugging info is turned on
        if s:debug
            call s:Warn("Invalid statement: ".a:stmt)
        endif
    endtry
endfu

function! s:SynID(group, ...) "{{{1
    let property = exists("a:1") ? a:1 : 'fg'
    let c1 = synIDattr(synIDtrans(hlID(a:group)), property)
    " since when can c1 be negative? Is this a vim bug?
    " it used to be empty on errors or non-existing properties...
    if empty(c1) || c1 < 0
        return ''
    else
        return c1
    endif
endfu

function! s:GenerateColors(dict) "{{{1
    let result=copy(a:dict)

    if !has_key(result, 'bg') && has_key(result, 'ctermbg')
        let result.bg = s:Term2RGB(result.ctermbg)
    elseif !has_key(result, 'bg') && has_key(result, 'guibg')
        let result.bg = result.guibg
    endif
    if !has_key(result, 'fg') && has_key(result, 'ctermfg')
        let result.fg = s:Term2RGB(result.ctermfg)
    elseif !has_key(result, 'fg') && has_key(result, 'guifg')
        let result.fg = result.guifg
    endif

    if !has_key(result, 'fg') &&
      \ has_key(result, 'bg')
        let result.fg = toupper(s:FGforBG(result.bg))
    endif
    if !has("gui_running")
        " need to make sure, we have ctermfg/ctermbg values
        if !has_key(result, 'ctermfg') &&
            \ has_key(result, 'fg')
            let result.ctermfg  = (s:term_true_color ? result.fg : s:Rgb2xterm(result.fg))
        endif
        if !has_key(result, 'ctermbg') &&
            \ has_key(result, 'bg')
            let result.ctermbg  = (s:term_true_color ? result.bg : s:Rgb2xterm(result.bg))
        endif
    endif
    for key in keys(result)
        if empty(result[key])
            let result[key] = 0
        endif
    endfor
    return result
endfunction

function! s:SetMatcher(pattern, Dict) "{{{1
    let param = s:GenerateColors(a:Dict)
    let clr = get(param, 'name', '')
    if empty(clr)
        let clr = 'Color_'. get(param, 'fg'). '_'. get(param, 'bg').
                \ (!empty(get(param, 'special', '')) ?
                \ ('_'. get(param, 'special')) : '')
    endif
    call s:SetMatch(clr, a:pattern, param)
endfunction

function! s:SetMatch(group, pattern, param_dict) "{{{1
    call s:DoHlGroup(a:group, a:param_dict)
    if has_key(a:param_dict, 'pos')
        call matchaddpos(a:group, a:param_dict.pos, s:default_match_priority)
        " do not add the pattern to the matchlist
        call add(w:match_list, a:pattern)
        return
    endif
    if s:DidColor(a:group, a:pattern)
        return
    endif
    " let 'hls' overrule our syntax highlighting
    if s:use_virtual_text
        call nvim_buf_set_virtual_text(0, 0, line('.')-1, [['  ', a:group]], {})
    else
        call matchadd(a:group, a:pattern, s:default_match_priority)
        call add(w:match_list, a:pattern)
    endif
endfunction
function! s:Xterm2rgb16(color) "{{{1
        " 16 basic colors
    let r=0
    let g=0
    let b=0
    let r = s:basic16[a:color][0]
    let g = s:basic16[a:color][1]
    let b = s:basic16[a:color][2]
    return [ r, g, b ]
endfunction

function! s:Xterm2rgb88(color) "{{{1
    " 16 basic colors
    let r=0
    let g=0
    let b=0
    if a:color < 16
       return s:Xterm2rgb16(a:color)

    " 4x4x4 color cube
    elseif a:color >= 16 && a:color < 80
        let color=a:color-16
        let r = s:valuerange4[(color/16)%4]
        let g = s:valuerange4[(color/4)%4]
        let b = s:valuerange4[color%4]
    " gray tone
    elseif a:color >= 80 && a:color <= 87
      let color = (a:color-80) + 0.0
      let r = 46.36363636 + color * 23.18181818 +
            \ (color > 0.0 ? 23.18181818 : 0.0) +  0.0
      let r = float2nr(r)
      let g = r
      let b = r
   endif

    let rgb=[r,g,b]
    return rgb
endfunction

function! s:Xterm2rgb256(color)  "{{{1
    " 16 basic colors
   let r=0
   let g=0
   let b=0
   if a:color < 16
       return s:Xterm2rgb16(a:color)

    " color cube color
    elseif a:color >= 16 && a:color < 232
      let color=a:color-16
      let r = s:valuerange6[(color/36)%6]
      let g = s:valuerange6[(color/6)%6]
      let b = s:valuerange6[color%6]

    " gray tone
    elseif a:color >= 232 && a:color <= 255
      let r = 8 + (a:color-232) * 0x0a
      let g = r
      let b = r
   endif
   let rgb=[r,g,b]
   return rgb
endfunction

function! s:RoundColor(...) "{{{1
    let result = []
    let minlist = []
    let min    = 1000
    let list = (&t_Co == 256 ? s:valuerange6 : s:valuerange4)
    if &t_Co > 16
        for item in a:000
            for val in list
                let t = abs(val - item)
                if (min > t)
                    let min = t
                    let r   = val
                endif
            endfor
            call add(result, r)
            call add(minlist, min)
            let min = 1000
        endfor
    endif
    if &t_Co <= 16
        let result  = [ a:1, a:2, a:3 ]
        let minlist = [ 255, 255, 255 ]
    endif
    " Check with the values from the 16 color xterm, if the difference
    " is lower
    let result = s:Check16ColorTerm(result, minlist)
    return result
endfunction

function! s:Check16ColorTerm(rgblist, minlist) "{{{1
" We only check those values for 256 color terminals here:
" [205,0,0] [0,205,0] [205,205,0] [205,0,205]
" [0,205,205] [0,0,238] [92,92,255]
" The other values are already included in the s:colortable list
    let min = a:minlist[0] + a:minlist[1] + a:minlist[2]
    if &t_Co == 256
        for value in [[205,0,0], [0,205,0], [205,205,0], [205,0,205],
                \ [0,205,205], [0,0,238], [92,92,255]]
            " euclidian distance would be needed,
            " but this works good enough and is faster.
            let t = abs(value[0] - a:rgblist[0]) +
                  \ abs(value[1] - a:rgblist[1]) +
                  \ abs(value[2] - a:rgblist[2])
            if min > t
                return value
            endif
        endfor
    elseif &t_Co == 88
        for value in [[0,0,238], [229,229,229], [127,127,127], [92,92,255]]
            let t = abs(value[0] - a:rgblist[0]) +
                    \ abs(value[1] - a:rgblist[1]) +
                    \ abs(value[2] - a:rgblist[2])
            if min > t
                return value
            endif
        endfor
    else " 16 color terminal
        " Check for values from 16 color terminal
        let best = []
        let min  = 100000
        let list = (&t_Co == 16 ? s:basic16 : s:basic16[:7])
        for value in list
            let t = abs(value[0] - a:rgblist[0]) +
                  \ abs(value[1] - a:rgblist[1]) +
                  \ abs(value[2] - a:rgblist[2])
            if min > t
                let min = t
                let best = value
            endif
        endfor
        return best
    endif
  return a:rgblist
endfunction

function! s:Ansi2Color(chars) "{{{1
    " chars look like this
    " [0m[01;32m
    if !exists("s:term2ansi")
        let s:term2ansi = {}
        " Color values taken from
        " https://en.wikipedia.org/wiki/ANSI_escape_code#Colors
        let s:term2ansi.std = { 30: printf("%.2X%.2X%.2X", 0,     0,   0),
                        \       31: printf("%.2X%.2X%.2X", 205,   0,   0),
                        \       32: printf("%.2X%.2X%.2X", 0,   205,   0),
                        \       33: printf("%.2X%.2X%.2X", 205, 205,   0),
                        \       34: printf("%.2X%.2X%.2X", 0,     0, 238),
                        \       35: printf("%.2X%.2X%.2X", 205,   0, 205),
                        \       36: printf("%.2X%.2X%.2X", 0,   205, 205),
                        \       37: printf("%.2X%.2X%.2X", 229, 229, 229),
                        \       90: printf("%.2X%.2X%.2X", 127, 127, 127),
                        \       91: printf("%.2X%.2X%.2X", 255,   0,   0),
                        \       92: printf("%.2X%.2X%.2X",   0, 255,   0),
                        \       93: printf("%.2X%.2X%.2X", 255, 255,   0),
                        \       94: printf("%.2X%.2X%.2X",  92,  92, 255),
                        \       95: printf("%.2X%.2X%.2X", 255,   0, 255),
                        \       96: printf("%.2X%.2X%.2X",   0, 255, 255),
                        \       97: printf("%.2X%.2X%.2X", 255, 255, 255)
                        \ }
        let s:term2ansi.bold = { 30: printf("%.2X%.2X%.2X", 127, 127, 127),
                        \        31: printf("%.2X%.2X%.2X", 255,   0,   0),
                        \        32: printf("%.2X%.2X%.2X", 0,   255,   0),
                        \        33: printf("%.2X%.2X%.2X", 255, 255,   0),
                        \        34: printf("%.2X%.2X%.2X",  92,  92, 255),
                        \        35: printf("%.2X%.2X%.2X", 255,   0, 255),
                        \        36: printf("%.2X%.2X%.2X", 0,   255, 255),
                        \        37: printf("%.2X%.2X%.2X", 255, 255, 255),
                        \        90: printf("%.2X%.2X%.2X", 127, 127, 127),
                        \        91: printf("%.2X%.2X%.2X", 255,   0,   0),
                        \        92: printf("%.2X%.2X%.2X",   0, 255,   0),
                        \        93: printf("%.2X%.2X%.2X", 255, 255,   0),
                        \        94: printf("%.2X%.2X%.2X",  92,  92, 255),
                        \        95: printf("%.2X%.2X%.2X", 255,   0, 255),
                        \        96: printf("%.2X%.2X%.2X",   0, 255, 255),
                        \        97: printf("%.2X%.2X%.2X", 255, 255, 255)
                        \ }
    endif

    let fground = ""
    let bground = ""
    let check = [0,0] " check fground and bground color

    if a:chars =~ '48;5;\d\+'
        let check[0] = 0
    elseif a:chars=~ '.*[39][0-7]\(;1\)\?[m;]'  " Check 30-37 and 90-97 colors
        let check[0] = 1
    elseif a:chars =~ '.*38\([:;]\)2\1'
        let check[0] = 2 " Uses True Color Support
    elseif a:chars =~ '.*38\([:;]\)5\1'
        let check[0] = 3 " Uses 256 Color Support
    endif
    if a:chars =~ '48;5;\d\+'
        let check[1] = 3
    elseif a:chars =~ '.*48\([:;]\)2\1'
        let check[1] = 2
    elseif a:chars=~ '.*4[0-7]\(;1\)\?[m;]'
        let check[1] = 1
    elseif a:chars=~ '.*10[0-7]\(;1\)\?[m;]'  " Same as 40-47
        let check[1] = 1
    endif

    if check[0] == 2
        " Check for TrueColor Support
        " Esc[38;2;<red>;<green>;<blue>
        " 38: background color
        " 48: foregournd color
        " delimiter could be either : or ;
        " skip leading ESC [ and trailing m char
        let pat = split(a:chars[2:-2], '[:;]')
        if pat[0] == 38 " background color
            let fground = printf("%.2X%.2X%.2X", pat[2], pat[3], pat[4])
        elseif a:pat[1] == 48 " foreground color
            let bground = printf("%.2X%.2X%.2X", pat[2], pat[3], pat[4])
        endif
    elseif check[0] == 3
        let nr = matchstr(a:chars, '\%x1b\[38;5;\zs\d\+\zem')
        let fground = s:Term2RGB(nr)
    elseif check[1] == 3
        let nr = matchstr(a:chars, '\%x1b\[48;5;\zs\d\+\zem')
        let bground = s:Term2RGB(nr)
    else
        for val in ["std", "bold"]
            for key in keys(s:term2ansi[val])
                let bright = (val == "std" ? "" : ";1")

                if check[0] " Check for a match of the foreground color
                    if a:chars =~ ".*".key.bright."[m;]"
                        let fground = s:term2ansi[val][key]
                    endif
                endif
                if check[1] "Check for background color
                    if a:chars =~ ".*".(key+10).bright."[m;]"
                        let bground = s:term2ansi[val][key]
                    endif
                endif
                if !empty(bground) && !empty(fground)
                    break
                endif
            endfor
            if !empty(fground) && !empty(bground)
                break
            endif
        endfor
    endif
    return [(empty(fground) ? 'NONE' : fground), (empty(bground) ? "NONE" : bground)]
endfunction

function! s:TermConceal(pattern) "{{{1
    " Conceals a list of patterns
    if exists("b:Colorizer_did_syntax")
        return
    endif
    let s:position = getpos('.')
    " concealing
    for pat in a:pattern
        exe "syn match ColorTermESC /". pat. "/ conceal containedin=ALL"
    endfor
    let &l:cole=2
    let &l:cocu=get(g:, 'colorizer_conceal_cursor_mode', 'nv')
    let b:Colorizer_did_syntax=1
endfu
function! s:GetColorPattern(list) "{{{1
    "let list = map(copy(a:list), ' ''\%(-\@<!\<'' . v:val . ''\>-\@!\)'' ')
    "let list = map(copy(a:list), ' ''\%(-\@<!\<'' . v:val . ''\>-\@!\)'' ')
    let list = copy(a:list)
    " Force the old re engine. It should be faster without backtracking.
    return '\%#=1\%(\<\('.join(copy(a:list), '\|').'\)\>\)'
endfunction

function! s:GetMatchList() "{{{1
    " this is window-local!
    return filter(getmatches(), 'v:val.group =~ ''^\(Color_\w\+\)\|NONE''')
endfunction

function! s:CheckTimeout(pattern, force) "{{{1
    " Abort, if pattern is not found within 100 ms and force
    " is not set
    return (!empty(a:force) || search(a:pattern, 'cnw', '', 100))
endfunction

function! s:SaveRestoreOptions(save, dict, list) "{{{1
    if a:save
        return s:SaveOptions(a:list)
    else
        for [key, value] in items(a:dict)
            if key !~ '@'
                call setbufvar('', '&'. key, value)
            else
                call call('setreg', [key[1]] + value)
            endif
            unlet value
        endfor
    endif
endfun

function! s:SaveOptions(list) "{{{1
    let save = {}
    for item in a:list
        if item !~ '^@'
            exe "let save.". item. " = &l:". item
        else
            let save[item] = []
            call add(save[item], getreg(item[1]))
            call add(save[item], getregtype(item))
        endif
        if item == 'ma' && !&l:ma
            setl ma
        elseif item == 'ro' && &l:ro
            setl noro
        elseif item == 'lz' && &l:lz
            setl lz
        elseif item == 'ed' && &g:ed
            setl noed
        elseif item == 'gd' && &g:gd
            setl nogd
        endif
    endfor
    return save
endfunction

function! s:StripParentheses(val) "{{{1
    return split(matchstr(a:val, '^\(hsl\|rgb\)a\?\s*(\zs[^)]*\ze)'), '\s*,\s*')
endfunction

function! s:ApplyAlphaValue(rgb) "{{{1
    " Add Alpha Value to RGB values
    " takes a list of [ rr, gg, bb, aa] values
    " alpha can be 0-1
    let bg = <sid>SynID('Normal', 'bg')
    if empty(bg)
        return a:rgb[0:3]
    else
        if !exists("s:colortable")
            call s:ColortableInit()
        endif
        if (bg =~? '\d\{1,3}') && bg < 256
            " Xterm color code
            " (add dummy in front of it, will be split later)
            let bg = '#'.join(s:colortable[bg])
        endif
        let rgb = []
        let bg_ = split(bg[1:], '..\zs')
        let alpha = str2float(a:rgb[3])
        if alpha > 1
            let alpha = 1 + 0.0
        elseif alpha < 0
            let alpha = 0 + 0.0
        endif
        let i = 0
        for value in a:rgb[0:2]
            let value += 0 " convert to nr
            let value = float2nr(ceil(value * alpha) + ceil((bg_[i]+0)*(1-alpha)))
            if value > 255
                let value = 255
            elseif value < 0
                let value = 0
            endif
            call add(rgb, value)
            let i+=1
            unlet value " reset type of value
        endfor
        return rgb
    endif
endfunction

function! s:HSL2RGB(h, s, l, ...) "{{{1
    let s = a:s + 0.0
    let l = a:l + 0.0
    if  l <= 0.5
        let m2 = l * (s + 1)
    else
        let m2 = l + s - l * s
    endif
    let m1 = l * 2 - m2
    let r = float2nr(s:Hue2RGB(m1, m2, a:h + 120))
    let g = float2nr(s:Hue2RGB(m1, m2, a:h))
    let b = float2nr(s:Hue2RGB(m1, m2, a:h - 120))
    if a:0
        let rgb = s:ApplyAlphaValue([r, g, b, a:1])
    endif
    return printf("%02X%02X%02X", r, g, b)
endfunction

function! s:Hue2RGB(m1, m2, h) "{{{1
    let h = (a:h + 0.0)/360
    if h < 0
        let h = h + 1
    elseif h > 1
        let h = h - 1
    endif
    if h * 6 < 1
        let res = a:m1 + (a:m2 - a:m1) * h * 6
    elseif h * 2 < 1
        let res = a:m2
    elseif h * 3 < 2
        let res = a:m1 + (a:m2 - a:m1) * (2.0/3.0 - h) * 6
    else
       let res = a:m1
    endif
    return round(res * 255)
endfunction

function! s:Rgb2xterm(color) "{{{1
" selects the nearest xterm color for a rgb value like #FF0000
" hard code values for 000000 and FFFFFF, they will be called many times
" so make this fast
    if a:color ==# 'NONE'
        return 'NONE'
    endif
    if len(a:color) <= 3
        " a:color is already a terminal color
        return a:color
    endif
    if !exists("s:colortable")
        call s:ColortableInit()
    endif
    let color = (a:color[0] == '#' ? a:color[1:] : a:color)
    if ( color == '000000')
        return 0
    elseif (color == 'FFFFFF')
        return 15
    else
        let r = '0x'.color[0:1]+0
        let g = '0x'.color[2:3]+0
        let b = '0x'.color[4:5]+0

        " Try exact match first
        let i = index(s:colortable, [r, g, b])
        if i > -1
            return i
        endif

        " Grey scale ?
        if ( r == g &&  r == b )
            if &t_Co == 256
                " 0 and 15 have already been take care of
                if r < 5
                    return 0 " black
                elseif r > 244
                    return 15 " white
                endif
                " grey cube starts at index 232
                return 232+(r-5)/10
            elseif &t_Co == 88
                if r < 23
                    return 0 " black
                elseif r < 69
                    return 80
                elseif r > 250
                    return 15 " white
                else
                    " should be good enough
                    return 80 + (r-69)/23
                endif
            endif
        endif

        " Round to the next step in the xterm color cube
        " euclidian distance would be needed,
        " but this works good enough and is faster.
        let round = s:RoundColor(r, g, b)
        " Return closest match or -1 if not found
        return index(s:colortable, round)
    endif
endfunction

function! s:Warn(msg) "{{{1
    let msg = 'Colorizer: '. a:msg
    echohl WarningMsg
    echomsg msg
    echohl None
    let v:errmsg = msg
endfu

function! s:LoadSyntax(file) "{{{1
    unlet! b:current_syntax
    exe "sil! ru! syntax/".a:file. ".vim"
endfu
function! s:HasGui() "{{{1
    return has("gui_running") || (exists("+tgc") && &tgc)
endfu
function! s:HasColorPattern() "{{{1
    let _pos    = winsaveview()
    try
        if !exists("s:colornamepattern")
            let s:colornamepattern = s:GetColorPattern(keys(s:colors))
        endif
        let pattern = values(s:color_patterns) + [s:colornamepattern]
        call cursor(1,1)
        for pat in pattern
            if s:CheckTimeout(pat, '')
                return 1
            endif
        endfor
        return 0

    finally
        call winrestview(_pos)
    endtry
endfunction

function! s:PrepareHSLArgs(list) "{{{1
    let hsl=a:list
    let hsl[0] = (matchstr(hsl[0], '\d\+') + 360)%360
    let hsl[1] = (matchstr(hsl[1], '\d\+') + 0.0)/100
    let hsl[2] = (matchstr(hsl[2], '\d\+') + 0.0)/100
    if len(hsl) == 4
        return s:HSL2RGB(hsl[0], hsl[1], hsl[2], hsl[3])
    endif
    return s:HSL2RGB(hsl[0], hsl[1], hsl[2])
endfu
function! s:SyntaxMatcher(enable) "{{{1
    if !a:enable
        return
    endif
    let did_clean = {}
    "
    let list=s:GetMatchList()
    if len(list) > 1000
        " This will probably slow
        call s:Warn("Colorizer many colors detected, syntax highlighting will probably slow down Vim considerably!")
    endif
    if &ft =~? 'css'
        " cssColor defines some color names like yellow or red and overrules
        " our colors
        sil! syn clear cssColor
    endif
    for hi in list
        if !get(did_clean, hi.group, 0)
            let did_clean[hi.group] = 1
            exe "sil! syn clear" hi.group
        endif
        if a:enable
            if has_key(hi, 'pattern')
                exe "syn match" hi.group "excludenl /". escape(hi.pattern, '/'). "/ display containedin=ALL"
            else
                " matchaddpos()
                let line=hi.pos1[0]
                let pos =hi.pos1[1]-1
                let len =hi.pos1[1]+hi.pos1[2]-2
                exe printf('syn match %s excludenl /\%%%dl\%%>%dc\&.*\%%<%dc/ display containedin=ALL', hi.group, line, pos, len)
            endif
            " We have syntax highlighting, can clear the matching
            " ignore errors (just in case)
            sil! call matchdelete(hi.id)
        endif
    endfor
endfu

function! Colorizer#ColorToggle() "{{{1
    if !exists("w:match_list") || empty(w:match_list)
        call Colorizer#DoColor(0, 1, line('$'))
    else
        call Colorizer#ColorOff()
    endif
endfu

function! Colorizer#ColorOff() "{{{1
    for _match in s:GetMatchList()
        sil! call matchdelete(_match.id)
    endfor
    call Colorizer#LocalFTAutoCmds(0)
    if exists("s:conceal")
      let [&l:cole, &l:cocu] = s:conceal
      if !empty(hlID('ColorTermESC'))
          syn clear ColorTermESC
      endif
    endif
    unlet! b:Colorizer_did_syntax w:match_list s:conceal
endfu

function! Colorizer#DoColor(force, line1, line2, ...) "{{{1
    " initialize plugin
    try
        if v:version < 800 && !has('nvim')
            call s:Warn("Colorizer needs Vim 8.0")
            return
        endif
        call s:ColorInit(a:force)
        if exists("a:1") && !empty(a:1)
            let s:color_syntax = ( a:1 =~# '^\%(syntax\|nomatch\)$' )
        endif
    catch /nocolor/
        " nothing to do
        call s:Warn("Your terminal doesn't support colors or no colors".
                    \ 'found in the current buffer!')
        return
    endtry
    let s:error = ""

    let _a   = winsaveview()
    let save = s:SaveRestoreOptions(1, {},
            \ ['mod', 'ro', 'ma', 'lz', 'ed', 'gd', '@/'])
    let s:relstart = s:Reltime()

    call s:ColorHighlight_1(a:force, a:line1, a:line2)
    call s:ColorHighlight_2(a:force, a:line1, a:line2)

    " convert matches into synatx highlighting, so TOhtml can display it
    " correctly
    call s:SyntaxMatcher(s:color_syntax)
    if !exists("#FTColorizer#BufWinEnter#<buffer>") && empty(s:error)
        " Initialise current window.
        call Colorizer#LocalFTAutoCmds(1)
        call Colorizer#ColorWinEnter(1, 1) " don't call DoColor recursively!
    endif
    let s:relstop = s:Reltime(s:relstart)
    if !empty(s:error)
        " Some error occurred, stop trying to color the file
        call Colorizer#ColorOff()
        call s:Warn("Some error occurred here: ". s:error)
        if exists("s:position")
            call s:Warn("Position: ". string(s:position))
            call matchadd('Color_Error', '\%'.s:position[1].'l\%'.s:position[2].'c.*\>')
        endif
    endif
    call s:PrintColorStatistics()
    call s:SaveRestoreOptions(0, save, [])
    call winrestview(_a)
endfu

function! Colorizer#RGB2Term(arg,bang) "{{{1
    if a:arg =~ '^rgb'
        let clr    = s:StripParentheses(a:arg)
        let color  = printf("#%02X%02X%02X", clr[0], clr[1], clr[2])
    else
        let color  = a:arg[0] == '#' ? a:arg : '#'.a:arg
    endif

    call s:ColorInit(1)
    let tcolor = s:Rgb2xterm(color)
    if empty(a:bang)
        call s:DoHlGroup("Color_". color[1:], s:GenerateColors({'bg': color[1:]}))
        exe "echohl" "Color_".color[1:]
        echo a:arg. " => ". tcolor
        echohl None
    endif
    return tcolor
endfu

function! Colorizer#Term2RGB(arg) "{{{1
    let index = a:arg + 0
    if a:arg > 255 || a:arg < 0
        call s:Warn('invalid index')
        return
    endif

    let _t_Co=&t_Co
    let &t_Co = 256
    call s:ColorInit(1)

    let rgb = s:Term2RGB(index)
    call s:DoHlGroup("Color_". rgb, s:GenerateColors({'bg': rgb, 'ctermbg': index}))
    exe "echohl" "Color_".rgb
    echo "TerminalColor: ". a:arg. " => ". rgb
    echohl None
    let &t_Co = _t_Co
endfu

function! Colorizer#HSL2Term(arg) "{{{1
    let hsl = s:StripParentheses(a:arg)
    if empty(hsl)
        call s:Warn("Error evaluating expression". a:val. "! Please report as bug.")
        return a:val
    endif
    let str = s:PrepareHSLArgs(hsl)

    let tcolor = s:Rgb2xterm('#'.str)
    call s:DoHlGroup("Color_".str, s:GenerateColors({'bg': str}))
    exe "echohl" str
    echo a:arg. " => ". tcolor
    echohl None
endfu

function! Colorizer#AutoCmds(enable) "{{{1
    if a:enable && !get(g:, 'colorizer_debug', 0)
        aug Colorizer
            au!
            if get(g:, 'colorizer_insertleave', 1)
              au InsertLeave *  sil call Colorizer#ColorLine('', line('w0'), line('w$'))
            endif
            if get(g:, 'colorizer_textchangedi', 1)
              au TextChangedI * sil call Colorizer#ColorLine('', line('.'),line('.'))
            endif
            if get(g:, 'colorizer_guienter', 1)
              au GUIEnter * sil call Colorizer#DoColor('!', 1, line('$'))
            endif
            if get(g:, 'colorizer_colorscheme', 1)
              au ColorScheme * sil call Colorizer#DoColor('!', 1, line('$'))
            endif
            if get(g:, 'colorizer_bufwinenter', 1)
              au BufWinEnter * sil call Colorizer#ColorWinEnter()
            endif
            if get(g:, 'colorizer_winenter', 1)
              au WinEnter * sil call Colorizer#ColorWinEnter()
            endif
        aug END
    else
        aug Colorizer
            au!
        aug END
        aug! Colorizer
    endif
endfu

function! Colorizer#LocalFTAutoCmds(enable) "{{{1
    if a:enable
        aug FTColorizer
            au!
            if !exists("#Colorizer#InsertLeave") && get(g:, 'colorizer_insertleave', 1)
              " InsertLeave autocommand already exists
              au InsertLeave <buffer> silent call
                        \ Colorizer#ColorLine('', line('w0'), line('w$'))
            endif
            if get(g:, 'colorizer_cursormovedi', 1)
              au CursorMovedI <buffer> call Colorizer#ColorLine('',line('.'), line('.'))
            endif
            if get(g:, 'colorizer_cursormoved', 1)
              au CursorMoved <buffer> call Colorizer#ColorLine('',line('.'), line('.'))
            endif
            if !exists("#Colorizer#BufWinEnter") && get(g:, 'colorizer_bufwinenter', 1)
              au BufWinEnter <buffer> silent call Colorizer#ColorWinEnter()
            endif
            if !exists("#Colorizer#WinEnter") && get(g:, 'colorizer_winenter', 1)
              au WinEnter <buffer> silent call Colorizer#ColorWinEnter()
            endif
            " disables colorizing on switching buffers inside a single window
            if get(g:, 'colorizer_bufleave', 1)
              au BufLeave <buffer> if !get(g:, 'colorizer_disable_bufleave', 0) | call Colorizer#ColorOff() |endif
            endif
            if !exists("#Colorizer#GUIEnter") && get(g:, 'colorizer_guienter', 1)
              au GUIEnter <buffer> silent call Colorizer#DoColor('!', 1, line('$'))
            endif
            if !exists("#Colorizer#ColorScheme") && get(g:, 'colorizer_colorscheme', 1)
              au ColorScheme <buffer> silent call Colorizer#DoColor('!', 1, line('$'))
            endif
        aug END
        if !exists("b:undo_ftplugin")
            " simply unlet a dummy variable
            let b:undo_ftplugin = 'unlet! b:Colorizer_foobar'
        endif
        " Delete specific auto commands, because the filetype
        " has been changed.
        let b:undo_ftplugin .= '| exe "sil! au! FTColorizer"'
        let b:undo_ftplugin .= '| exe "sil! aug! FTColorizer"'
        let b:undo_ftplugin .= '| exe ":call Colorizer#ColorOff()"'
    else
        aug FTColorizer
            au!
        aug END
        aug! FTColorizer
    endif
endfu

function! Colorizer#ColorWinEnter(...) "{{{1
    let force = a:0 ? a:1 : 0
    " be fast!
    if !force
        let ft_list = split(get(g:, "colorizer_auto_filetype", ""), ',')
        if match(ft_list, "^".&ft."$") == -1
            " current filetype doesn't match g:colorizer_auto_filetype,
            " so nothing to do
            return
        endif
        if get(b:, 'Colorizer_changedtick', 0) == b:changedtick &&
                    \ !empty(getmatches())
            " nothing to do
            return
        endif
    endif
    let g:colorizer_only_unfolded = 1
    let _c = getpos('.')
    if !exists("a:2")
        " don't call it recursively!
        call Colorizer#DoColor('', 1, line('$'))
    endif
    let b:Colorizer_changedtick = b:changedtick
    unlet! g:colorizer_only_unfolded
    call setpos('.', _c)
endfu

function! Colorizer#ColorLine(force, start, end) "{{{1
    if get(b:, 'Colorizer_changedtick', 0) == b:changedtick && empty(a:force)
        " nothing to do
        return
    else
        call Colorizer#DoColor(a:force, a:start, a:end)
        let b:Colorizer_changedtick = b:changedtick
    endif
endfu

function! Colorizer#SwitchContrast() "{{{1
    if exists("s:swap_fg_bg") && s:swap_fg_bg
        call s:Warn('Contrast Adjustment does not work with swapped foreground colors!')
        return
    endif
    if !exists("s:predefined_fgcolors")
        " init variables
        call s:ColorInit('')
    endif
    " make sure, g:colorizer_fgcontrast is set up
    if !exists('g:colorizer_fgcontrast')
        " Default to black / white
        let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
    endif
    let g:colorizer_fgcontrast-=1
    if g:colorizer_fgcontrast < -1
        let g:colorizer_fgcontrast = len(s:predefined_fgcolors['dark']) - 1
    endif
    echom 'Colorizer: using fgcontrast' g:colorizer_fgcontrast
    call Colorizer#DoColor(1, 1, line('$'))
endfu

function! Colorizer#SwitchFGBG() "{{{1
    let range = [ 0, 1, -1 ]
    if !exists("s:round")
        let s:round = 0
    else
        let s:round = (s:round >= 2 ? 0 : s:round+1)
    endif
    let s:swap_fg_bg = range[s:round]
    call Colorizer#DoColor(1, 1, line('$'))
endfu

" DEBUG TEST "{{{1
if !get(g:, 'colorizer_debug', 0)
    let &cpo = s:cpo_save
    unlet s:cpo_save
    finish
endif

fu! ColorizerXtermColors() "{{{2
    let list=[]
    for c in range(0, 254)
        let css_color = s:Xterm2rgb256(c)
        call add(list, css_color)
    endfor
   return list
endfu

fu! ColorizerGet(args) "{{{2
    exe "return s:".a:args
endfu

" Plugin folklore and Vim Modeline " {{{1
let &cpo = s:cpo_save
unlet s:cpo_save
" vim: set foldmethod=marker et fdl=0:
