# fluent-plugin-prometheus-pull

[Fluentd](https://fluentd.org/) input plugin to pull prometheus http endpoint.


## plugins

### input - prometheus_pull

Pull http prometheus metric endpoint.

with options:

| options             | default | usage                                                |
|---------------------|---------|------------------------------------------------------|
|                     |         |                                                      |
| event_url_key       | nil     | define the key that will store the fetched url       |
| event_url_label_key | nil     | define the key that will store the fetched url label |

Example:

```
<source>
  @type prometheus_pull
  urls http://app/metrics,http://app2/metrics
  interval 300s

  tag metric

  <parse>
    @type prometheus_text
    label_prefix  tags_
    add_type false
  </parse>
</source>
```

### parser - prometheus_text

Take a "text" (string) of prometheus content, fetched by any mechanism you want,
then it parses it, transforming each line in 1 event.

with options:
* ...
* ...

Example:

```
<parse>
  @type prometheus_text
  label_prefix tags_
  add_type false
</parse>
```

## Installation

Manual install, by executing:

    $ gem install fluent-plugin-prometheus-pull

Add to Gemfile with:

    $ bundle add fluent-plugin-prometheus-pull


## Compatibility

plugin will work with:
- ruby >= 2.7.7
- td-agent >= 4.0.0


## Copyright

* Copyright(c) 2023-2024 Thomas Tych
* License
  * Apache License, Version 2.0
