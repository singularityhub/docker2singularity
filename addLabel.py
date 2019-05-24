#!/usr/bin/env python

'''

add.py: wrapper for "add" of a key to a json file for
        Singularity Hub command line tool.

This function takes input arguments of the following:

   --key: should be the key to lookup from the json file
   --value: the value to add to the key
   --file: should be the json file to read

Copyright (c) 2019, Vanessa Sochat. All rights reserved.

'''

import sys
import os
import json
import argparse

def get_parser():

    parser = argparse.ArgumentParser(description="GET key from json")

    parser.add_argument("--key",
                       dest='key',
                       help="key to add to json",
                       type=str,
                       default=None)

    parser.add_argument("--value",
                       dest='value',
                       help="value to add to the json",
                       type=str,
                       default=None)

    parser.add_argument("--file",
                       dest='file',
                       help="Path to json file to add to",
                       type=str,
                       default=None)

    parser.add_argument('-f', dest="force",
                       help="force add (overwrite if exists)",
                       default=False, action='store_true')

    parser.add_argument('--quiet', dest="quiet",
                       help="do not display debug",
                       default=False, action='store_true')

    return parser


def write_json(json_obj, filename, mode="w", print_pretty=True):
    '''write_json will (optionally,pretty print) a json object to file
    '''
    bot.verbose2("Writing json file %s with mode %s." % (filename, mode))
    with open(filename, mode) as filey:
        if print_pretty is True:
            filey.writelines(print_json(json_obj))
        else:
            filey.writelines(json.dumps(json_obj))
    return filename


def read_json(filename, mode='r'):
    '''read_json reads in a json file and returns
    the data structure as dict.
    '''
    with open(filename, mode) as filey:
        data = json.load(filey)
    return data


def ADD(key, value, jsonfile, force=False, quiet=False):
    '''ADD will write or update a key in a json file
    '''

    # Check that key is not empty
    if key.strip() in ['#', '', None]:
        bot.verbose('Empty key %s, skipping' % key)
        sys.exit(0)

    key = format_keyname(key)
    print("Adding label: '%s' = '%s'" % (key, value))
    print("ADD %s from %s" % (key, jsonfile))

    if os.path.exists(jsonfile):
        contents = read_json(jsonfile)
        if key in contents:
            msg = 'Warning, %s is already set. ' % key
            msg += 'Overwrite is set to %s' % force
            if not quiet:
                print(msg)
            if force is True:
                contents[key] = value
            else:
                msg = '%s found in %s ' % (key, jsonfile)
                msg += 'and overwrite set to %s.' % force
                print(msg)
                sys.exit(1)
        else:
            contents[key] = value
    else:
        contents = {key: value}

    print('%s is %s' % (key, value))
    write_json(contents, jsonfile)
    return value


def main():

    parser = get_parser()

    try:
        (args, options) = parser.parse_args()
    except Exception:
        sys.exit(0)

    if args.key is not None and args.file is not None:
        if args.value is not None:

            value = ADD(key=args.key,
                        value=args.value,
                        jsonfile=args.file,
                        force=args.force,
                        quiet=args.quiet)

    else:
        bot.error("--key and --file and --value must be defined for ADD.")
        sys.exit(1)


if __name__ == '__main__':
    main()
