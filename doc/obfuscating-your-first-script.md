# Obfuscating your first script

Now that you have downloaded and Prometheus, you probably wonder how to use it. In this quick tutorial you are going to learn how to obfuscate your first file.

Note that in the following command examples `lua` should be replaced by your lua implementation.

Create the following file within the Prometheus main directory that you just downloaded:

{% code title="hello_world.lua" %}
```lua
print("Hello, World")
```
{% endcode %}

Now run the following command inside of the Prometheus directory:

```batch
lua ./cli.lua ./hello_world.lua
```

This should create the following file:

{% code title="hello_world.obfuscated.lua" %}
```lua
print("Hello, World")
```
{% endcode %}

As you can see, the file hasn't changed at all. That is because by default prometheus is just a minifier and the code we gave it was already as small as possible. To actually obfuscate the file, prometheus must be told which obfuscation steps it should apply in which order. In order to do this, the cli provides the `--preset` option which allows you to specify the name of a predefined configuration. There are currently only two presets:

* Minify
* Strong

In order to perform the obfuscation, you need to specify that Prometheus should use the Strong preset:

```batch
lua ./cli.lua --preset Strong ./hello_world.lua
```

The `hello_world.obfuscated.lua` should now become around 20kB in size, but when running, it should still print "Hello World".
