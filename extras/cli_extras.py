import argparse

def main:
 parser = argparse.ArgumentParser
 parser.add_argument('--foo', help='Foo help')
 args = parser.parse_args
 print(args.foo)