from importlib.resources import path
import discord
from discord.ext import commands
import requests
import os
from os import system
import subprocess
import shutil
import string
import random

token = "YOUR-TOKEN-HERE"                    # token
channel_id = CHANNEL-ID-HERE                 # channel id 

file_path = os.path.abspath(os.path.dirname(__file__))

bot = commands.Bot(command_prefix="!")
bot.remove_command("help")
letters = string.ascii_uppercase
filename = ''.join(random.choice(letters) for i in range(7))

def obfuscation(file):
    subprocess.check_output(f'lua ./cli.lua --preset Medium {file}')
    os.remove(file)

@bot.event
async def on_ready():
    print(f"{bot.user} is online ✔️")
    await bot.change_presence(status=discord.Status.online, activity=discord.Game(name="prometheus lua obfuscator"))

@bot.event
async def on_message(message):
    channel = str(message.channel)
    author=str(message.author)
    channel = bot.get_channel(channel_id)

    try:
        url = message.attachments[0].url
        if not message.author.bot:
            if message.channel.id == channel_id:
                if message.attachments[0].url:
                    if '.lua' not in url:
                        embed=discord.Embed(title=f"***Wrong file extension!***", description=f"only ``.lua`` allowed", color=0xFF3357)
                        message = await channel.send(embed=embed)
                    else:
                        obfuscated_dir = f"{file_path}\\obfuscated\\"

                        if not os.path.exists(obfuscated_dir):
                            os.makedirs(obfuscated_dir)
                            
                        print(f'\nNew lua script received from {author}.')
                        print(f'Attachment Link: {message.attachments[0].url}\n')
                        response = requests.get(url)
                        path = f"{file_path}\\obfuscated\\{filename}.lua"

                        open(path, "wb").write(response.content)
                        obfuscation(path)
                        embed=discord.Embed(title="File has been obfuscated", color=0x3357FF)
                        await channel.send(embed=embed, file=discord.File(f"{file_path}\\obfuscated\\{filename}.obfuscated.lua"))
                        os.remove(f"{file_path}\\obfuscated\\{filename}.obfuscated.lua")
    except:
        pass

bot.run(token)
