# nginx-lua-swift

## Sample nginx configuration

```
    location ~ /ceph(.*)$ {
        set $path $1;
        
        content_by_lua_file "/etc/nginx/lua/swift";

        error_page 404 @404;
    }

    location @404 {
        echo 'Do what you want';
    }
```
