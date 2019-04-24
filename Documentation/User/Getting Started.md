
# Getting Started

This guide contains a basic introduction on how to use _Live Lightshow_.
It will introduce its basic concepts and show you how to apply them in practice.

## Concepts

### Servers
_Live Lightshow_ is based around the concept of _servers_. A server is something that knows how to convert audio input into visual output. It can do so any way it likes.
For example you could have one server that specifically analyzes certain audio features that are associated with vocals, and produce its output from that. Or you could have a server which just produces ouput when the audio is louder than a certain threshold.

### Server Instances
Now when you run a light show, you can have any number of servers running at the same time. And specifically, you can have multiple servers of the same _type_ running at once. Each one of these running servers is called and _instance_. So you can have as many _instances_ running as you want, where multiple instances can be of the same _server_ type. The reason you might want to run multiple instances of the same server, is that you can configure instances.

### Server Traits
To allow you to customize your light show, servers can provide customizable _traits_. A trait is just some named value, which is used by a server in its audio conversion process.
So using the example of a server which just produces output if the audio's loudness is above a certain threshold: this server could provide a trait called _threshold_ whose value you can decide.
And while the _kinds_ of traits that you have access to are the same for each instance of a given server, the _values_ of those traits can be different for each instance.
So for example, you could have two instances of the loudness-server running. Both instances would only provide the _threshold_ trait, but the first instance might give it a value of 10, while the second one gives it a value of 100.

### Trait Value Types
To make sure that you don't misinterpret what value a trait expects, each trait value has a _type_.
Possible trait value types are:
* _Integer_
	* whole numbers like `0`, `42`, or `-10`
* _Float_
	* floating-point numbers like `0.0`, `3.14` or `-10.0`
* _Boolean_
	* the truth-values `true` or `false`
* _Integer-List_
	* a list of _Integer_ values like `[0, 42, -10]`, `[5]` or `i[]` for the empty _Integer-List_
*  _Float-List_
	* a list of _Float_ values like `[0.0, 3.14, -10.0]`, `[0.5]` or `f[]` for the empty _Float-List_
* _Boolean-List_
	* a list of _Boolean_ values like `[true, false, false]`, `[true]` or `b[]` for the empty _Boolean-List_

It should be noted that _Float_ values always require the decimal `.` even when specifying whole numbers like `10.0`. List values require the opening and closing brackets `[`, `]`. And _Boolean_ values need to be lowercase.
Leading and trailing whitespace around values is ignored.

## Using _Live Lightshow_

Now that you have an understanding of the concepts of _Live Lightshow_, lets look at how to use them in practice.

You can control a light show using the `lightshow` command. This command takes a couple of subcommands which allow you to do different things.

### `initialize` :
Before starting a light show, you might need to call:

```bash
 lightshow initialize
```

 This will load the required program onto your _Arduino_.
 You will only ever need to call this command, if you have loaded another program onto your _Arduino_ between uses of this program.

### `start` :
Once initialized, you can start a light show by calling:

```bash
 lightshow start
```
This command starts out by prompting you in _vi_, to specify which server instances you want to be running. You need to give each instance a unique name, and a valid sever type.
The types of servers you can choose from will be those provided with this project, as well as those developed by other developers, if you have installed them.
So for example, to start a lightshow with three instances of the `default` server, called `lows`, `mids` and `highs`, you would provide the following:

```bash
lows:  default
mids:  default
highs: default
```

Leading and trailing whitespace in given names is ignored.

After providing a valid list of server instances, the light show will start feeding the audio signal of your computer's current audio line-in to the server instances. Changing the audio line-in while a light show is running will have no effect, so make sure to choose the correct one beforehand.

### `status`  :
If you are unsure whether a light show is currently running, you can call:

```bash
lightshow status
```

This will tell you whether a light show is currently running, as well as providing you with information about the instances of a running light show. The output for the light show started above would be something like:

```bash
A light show is currently running with the following setup:

Instance 'lows' of server type 'default'
◦ Frequency Bounds: [0.0, 20000.0]
◦ Output Pins: [5]

Instance 'mids' of server type 'default'
◦ Frequency Bounds: [0.0, 20000.0]
◦ Output Pins: [5]

Instance 'highs' of server type 'default'
◦ Frequency Bounds: [0.0, 20000.0]
◦ Output Pins: [5]
```

The bulleted points beneath each instance are its traits. As you can see each instance currently has the same values for their trait. These values are default values provided by the developer of the server.

### `configure`  :
To configure the traits of a server instance, you call:

```bash
lightshow configure <instance name>
```

This will open _vi_ with the configuration of the specified instance. You can then change the values of the specified traits. Deleting a trait will cause the server instance to use its default value. Specifying a trait value with an incorrect type, will cause the program to ask you to change the value to a valid one.

Following the example above, we could reconfigure the `mids` instance to use different output pins:

```bash
lightshow configure mids
```

This will open _vi_ with:

```bash
Frequency Bounds: [0.0, 20000.0]
Output Pins: [5]
```

We can then change the trait values to:

```bash
Frequency Bounds: [0.0, 20000.0]
Output Pins: [2, 3, 4]
```

Once you have reconfigured an instance's traits, it might take a moment to see the change in the visual output.  


### `end`  :

Ending a light show is as simple as calling `lightshow end`.

### `directory` and `reindex`:

These commands are meant for developers. If you want to develop servers for this project, please check out the [Developer](https://github.com/marcusrossel/live-lightshow/tree/master/Documentation/Developer) section of the documentation.
