# demo/curl-demo.tape — proof VHS runs real commands in a real shell (live network).
Output demo-out/curl-demo.gif
Source demo/config.tape
Hide
Type "export PS1='$ '" Enter
Type "clear" Enter
Show
Type@30ms "curl -s https://api.github.com/repos/charmbracelet/vhs \" Enter
Type@30ms "  | jq '{name, stars: .stargazers_count, license: .license.spdx_id}'" Enter
Wait
Sleep 2500ms
Screenshot demo-out/curl-frame.png
