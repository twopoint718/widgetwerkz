# WidgetWerkz

WidgetWerkz specializes in the production and distribution of high quality widgets.
Through our groundbreaking use of _Relational Database Management Systems_ we've cornered the European Widget market!

## Usage

Install [sqitch](https://sqitch.org), we'll be using PostgreSQL so pay attention to just that part of the instructions.
After sqitch is installed:

```
createdb widgetwerkz
sqitch deploy
```

You should see

```
Deploying changes to db:pg:widgetwerkz
  + user_management .. ok
  + api_schema ....... ok
  + seed_db .......... ok
```

## Supporting

```
sudo brew services restart denji/nginx/nginx-full && date
```
