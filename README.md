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
    
Specifies the annotation symbol, the default annotation symbol is "#" and ";".
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

Reading a configuration file.
returns the specified default value if the specified key does not exist.
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

Modifying a configuration file.
supports specifying whether 'value' uses quotation marks.
=========================================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.set("Author","name","lhf")
    cfg.set("Author","qq","10214028",false) # Do not use double quotes for storage
    cfg.write("config.ini")
    echo cfg

Deleting a section key in a configuration file.
===============================================

    import parseini
    var cfg = loadConfig("config.ini")
    cfg.del("Author","email")
    cfg.write("config.ini")
    echo cfg
