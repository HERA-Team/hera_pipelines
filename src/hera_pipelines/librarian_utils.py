import asyncio
import json
import time
from pathlib import Path

from hera_librarian import LibrarianClient


def search_day_autos(day):
    # Let's do it
    print(f"Searching for all autos on librarian for day {day}")
    client = LibrarianClient('local')
    return client.search_files(get_day_of_auto_search_string(day))['results']

def get_day_of_auto_search_string(day: int | str):
    return f'{{"start-time-jd-greater-than": {day}, "start-time-jd-less-than": {int(day)+1}, "name-matches": "%.autos.uvh5"}}'

async def stage_autos_for_a_day(dest: Path, day: int, clobber: bool = False):
    """
    Tell the Librarian to stage files onto the local scratch disk.
    """
    # Let's do it
    client = LibrarianClient('local')

    # Get the username. We could make this a command-line option but I think it's
    # better to keep this a semi-secret. Note that the server does absolutely no
    # verification of the values that are passed in.

    import getpass

    user = getpass.getuser()

    # Resolve the destination in case the user provides, say, `.`, where the
    # server is not going to know what that means. This will need elaboration if
    # we add options for the server to come up with a destination automatically or
    # other things like that.
    our_dest = dest.resolve()

    marker_path = dest / "STAGING-IN-PROGRESS"
    t0 = time.time()

    if not marker_path.exists():
        _search = get_day_of_auto_search_string(day)
        result = client.launch_local_disk_stage_operation(user, _search, str(our_dest))

        print(
            "Launched operation to stage {:d} instances ({:d} bytes) to {}".format(
                result["n_instances"], result["n_bytes"], dest
            )
        )
    else:
        print(f"Operation to stage day {day} already underway, waiting...")


    t0 = time.time()

    while marker_path.exists():
        await asyncio.sleep(3)

    if (dest /"STAGING-SUCCEEDED").exists():
        return

    try:
        with open(dest / "STAGING-ERRORS") as fl:
            msg = f"Staging completed , but with error!\n\n{fl.read()}"
        raise Exception(msg)
    except OSError as e:
        raise OSError(
            'staging finished but neiher "success" nor "error" indicator was '
            f"created (no file {dest}/STAGING-ERRORS)"
        ) from e



async def stage_day(stage_dir, root_stage, day):
    day = str(day)
    day_stage = stage_dir / day
    if not day_stage.exists():
        day_stage.mkdir()

    # Cache the result of the search, because it takes a little time.
    result_fl = (day_stage / "auto-search-result.json")
    if result_fl.exists():
        with open(result_fl) as fl:
            fls_in_librarian = json.load(fl)
    else:
        fls_in_librarian = search_day_autos(day)
        with open(result_fl, 'w') as fl:
            json.dump(fls_in_librarian, fl)

    fls_on_lustre = list((root_stage / day).glob("*.autos.uvh5"))

    # I'm not sure if the librarian overwrites files. Let's do
    # a softlink to any files on lustre anyway, in case the librarian
    # acknowledges them and skips over existing files.
    stage_day_day = day_stage / day
    if not stage_day_day.exists():
        stage_day_day.mkdir()

    for fl in fls_on_lustre:
        fl_on_stage = stage_day_day / fl.name
        if not fl_on_stage.exists():
            fl_on_stage.symlink_to(fl)

    fls_staged = list(stage_day_day.glob("*.autos.uvh5"))
    if len(fls_staged) != len(fls_in_librarian):
        print(f"Staging all autos for day {day}")
        await stage_autos_for_a_day(dest=day_stage, day=day)
