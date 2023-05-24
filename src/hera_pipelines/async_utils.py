import asyncio


async def subprocess_run(cmd: str, **kw):
    proc = await asyncio.create_subprocess_shell(
        cmd,
        stdout=asyncio.subprocess.PIPE,
        stderr=asyncio.subprocess.PIPE,
        **kw
    )

    stdout, stderr = await proc.communicate()

    if stdout:
        print(f'{cmd!r}:\n[stdout]\n{stdout.decode()[:100]}')
    if proc.returncode:
        raise OSError(
            f"""{cmd!r} exited with {proc.returncode}.

[stderr] ---------------------------
{stderr.decode()}
------------------------------------
""")


async def gather_with_concurrency(n, *coros):
    """Run a number of coroutines, but only ever n at a time"""
    semaphore = asyncio.Semaphore(n)

    async def sem_coro(coro):
        async with semaphore:
            return await coro
    return await asyncio.gather(*(sem_coro(c) for c in coros))
