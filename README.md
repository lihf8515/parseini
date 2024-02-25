# parseini
A high-performance ini parse library for nim.
the ``parseini`` module implements a high performance configuration file
parser, evolved from ``parsecfg``.
the configuration file's syntax is similar to the Windows ``.ini``
format, but much more powerful, as it is not a line based parser. string
literals, raw string literals and triple quoted string literals are 
supported as in the nim programming language.
the module supports annotation statements, does not delete comment
statements and redundant blank characters, leaving the original style
and you can specify annotation delimiters.


This is a simple example of a configuration file.
=================================================

    charset="utf-8"
    [Package]
    name="hello"
    --threads:"on"
    [Author]
    name="lihf8515"
    qq="10214028"
    email="lihaifeng@wxm.com"
    
Specify annotation symbols, default annotation symbols are "#" and ";".
The following example replaces the annotation symbol with "&".
==============================================================================

    import parseini
    var cfg=loadConfig("config.ini","&")
    
Support for read-write multivalued key.
=======================================
    [Author]
    name="lihf8515"
    name = Li haifeng

    import parseini
    var cfg=loadConfig("config.ini")
    cfg.add("Author","name","lhf")
    echo cfg.gets("Author","name")
    
Creating a configuration file.
==============================

    import parseini
    var cfg=newConfig()
    cfg.set("","charset","utf-8")
    cfg.set("Package","name","hello")
    cfg.set("Package","--threads","on")
    cfg.set("Author","name","lihf8515")
    cfg.set("Author","qq","10214028")
    cfg.set("Author","email","lihaifeng@wxm.com")
    cfg.write("config.ini")
    echo cfg

Read the configuration file.
If the specified key does not exist, return an empty string.
Support custom default return values.
========================================================================

    import parseini
    var cfg = loadConfig("config.ini")
    var charset = cfg.get("","charset")
    var threads = cfg.get("Package","--threads")
    var pname = cfg.get("Package","name")
    var name = cfg.get("Author","name")
    var qq = cfg.get("Author","qq")
    var email = cfg.get("Author","email","10214028@qq.com")
    echo pname & "\n" & name & "\n" & qq & "\n" & email

Modify the configuration file. Support whether key values use quotation marks.
When the last parameter is false, it indicates that the key value does not need to be wrapped in double quotes during actual storage.
=========================================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.set("Author","name","lhf")
    cfg.set("Author","qq","10214028",false)
    cfg.write("config.ini")
    echo cfg

Delete key value pairs in the configuration file.
===============================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.del("Author","email")
    cfg.write("config.ini")
    echo cfg
