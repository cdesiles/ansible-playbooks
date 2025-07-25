# Ansible Gists

Scripts that took time to write and that I'm not sure I will use again.

## Convert netmask to CIDR notation

```yml
- name: Convert netmask to CIDR notation
  set_fact:
      cidr_notation: >-
          {{
            (interface.netmask.split('.') |
             map('int') |
             map('string') |
             map('regex_replace', '^(.*)$', '\\1|int|format("08b")') |
             map('regex_replace', '^(.*)$', '{{\\1}}') |
             join('') |
             regex_replace('0+$', '') |
             length)
          }}
  when: interface.netmask is defined and network_file.stat.exists != true
```
