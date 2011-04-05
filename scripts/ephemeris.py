#!/usr/bin/env python

import sys
import json
import yaml
from pprint import pprint

import swisseph as swe

if __name__ == "__main__":

  if not sys.argv[1:]:
    print >>sys.stderr, sys.argv[0] + " is useless without input"
    sys.exit(1)
  else:
    try:
      re = json.loads(sys.argv[1])
    except ValueError, e:
      print >>sys.stderr, "Could not load JSON object from argv[1]: " + sys.argv[1]
      sys.exit(1)

    swe.set_ephe_path(re["data"]) # set path to ephemeris data files

    # e[phemeris]:
    # angles (ascmc) = 10 doubles (a[8] & a[9] unused)
    # things (main bodies / points)
    # minors (other objects)
    # houses (cusps)  = 13 doubles (c[0] unused)
    e = {"angles": {}, "things": {}, "minors": {}, "houses": {}}

    # TODO: the flag is hardcoded to Gregorian calendar - correct?
    t = swe.utc_to_jd(re["ut"][0], re["ut"][1], re["ut"][2], re["ut"][3], re["ut"][4], re["ut"][5], 1)
    # e["jd-ut1"] = swe.jdut1_to_utc(t[1], 1)
    for o in [{"what": "things", "offset": 0}, {"what": "minors", "offset": 10000}]:
      for w in re[o["what"]]:
        result = swe.calc_ut(t[1], (w + o["offset"]))
        output = {}
        for out in re["ecliptic"]:
          output[out] = result[out]
        e[o["what"]][w] = output

    if re["geo"]["lat"] and re["geo"]["lon"]:
      e["houses"], e["angles"] = swe.houses(t[1], float(re["geo"]["lat"]), float(re["geo"]["lon"]), str(re["system"]))

    if re["out"] == "print":
      print(e)
    elif re["out"] == "pprint":
      # make it readable using swe.get_planet_name
      for (what, offset) in {"things": 0, "minors": 10000}.iteritems():
        replace = {}
        for (key, val) in e[what].iteritems():
          replace[swe.get_planet_name(key + offset)] = val
        e[what] = replace
      pprint(e)
    elif re["out"] == "yaml":
      print yaml.safe_dump(e) #, default_flow_style=False, canonical=True, encoding='utf-8'
    else:
      # json is the default
      print json.JSONEncoder().encode(e)

    sys.stdout.flush()

# TODO: research $ python -u
# unbuffered binary stdout and stderr; also PYTHONUNBUFFERED=x
# see man page for details on internal buffering relating to '-u'
