use std::env;
use std::fs;
use std::io;
use std::path::Path;
use fs::read_dir;
use std::collections::HashMap;


fn atomic_symlink(source: &str, target: &str) -> io::Result<()> {
    let tmp = format!("{target}.tmp");
    if Path::new(&tmp).exists() {
        _ = fs::remove_file(tmp.clone());
    }
    match std::os::unix::fs::symlink(source, tmp.clone()) {
        Ok(()) => {},
        Err(err) => {
            eprintln!("Could not create symlink: {err}");
        }
    }
    // TODO: rename is atomic but will fail if /etc/static is a directory so check here.
    fs::rename(tmp, target).expect("Could not rename tmp symlink to target! {err}");
    Ok(())
}

fn is_static(path: &Path) -> bool {
    if path.is_symlink() {
        match path.canonicalize() {
            Ok(p) => {
                return p.starts_with("/etc/static");
            },
            Err(err) => {
                eprintln!("Could not lookup path metadata! {err}");
                return false;
            }
        }
    }
    if path.is_dir() {
        let paths = fs::read_dir("./").unwrap();
        for entry in paths {
            let entry = entry.unwrap();
            let path = entry.path();
            if !is_static(&path) {
                eprintln!("{} is not static!", path.display());
                return false;
            }
        }
    }
    return false;
}

fn cleanup(path: &Path) {
    //let path = Path::new(p);
    // TODO: ignore /etc/nixos ?
    if !path.is_symlink() {
        return;
    }
    let target = path.canonicalize().unwrap();
    if target.starts_with("/etc/static") {
        let tail = &path.to_str().unwrap()[4..];
        let new_x = &format!("/etc/static/{tail}");
        let x = Path::new(new_x);
        if !x.is_symlink() {
            println!("removing obsolete symlink {}", path.display());
            _ = fs::remove_file(path.to_str().unwrap());
        }
    }
}
// https://stackoverflow.com/questions/63542762/directory-traversal-in-vanilla-rust
fn find(path: &Path, f: fn(&Path)) -> io::Result<()> {
    for e in read_dir(path)? {
        let e = e?;
        let path = e.path();
        if path.is_dir() {
            find(&path, f)?;
        } else if path.is_file() {
            f(path.as_path());
        }
    }
    Ok(())
}

// etc = $etc
// name = $File::Find::name
// %created hashmap
// @copied array
fn link(&etc: str, &name: str) {
    let mut created = HashMap::new();
    // or next: if name.length() <= etc.length() then return?
    let file_name = &name[..(etc.chars().count() + 1)];

    if (file_name == "resolve.conf") {
        match env::var("IN_NIXOS_ENTER") {
            Ok(()) => { return; },
            Err(()) => {}
        }
    }

    let target = Path::new(&format!("/etc/{file_name}"));
    fs::create_dir_all(target.parent()).unwrap();
    created.insert(file_name, 1);

    let fileMeta = fs::metadata(name).unwrap();
    let targetMeta = fs::metadata(target).unwrap();
    if (fileMeta.is_symlink() && targetMeta.is_dir()) {
        if is_static(target) {
           // try (rmTree target) or warn
        } else {
            eprintln!("{} directory contains user files. Symlinking may fail", target);
        }
    }
    if (-e "{file_name}.mode") {
        let mode = fs::read_to_string(&format!("{name}.mode"))
            .expect("Should have been able to read the file").trim_right();
        if ($mode == "direct-symlink") {
            atomic_symlink(&format!("/tmp/etc/static/{file_name}", $target).expect(format!("Could not create symlink {target}"));
        } else {
            let tmpTarget = &format!("{target}.tmp");
            let uid = fs::read_to_string(&format!("{name}.uid"))
                .expect("Should have been able to read the file").trim_right();
            let gid = fs::read_to_string(&format!("{name}.gid"))
                .expect("Should have been able to read the file").trim_right();
            fs::copy(&format!("/tmp/etc/static/{file_name}"), tmpTarget).expect("Could not copy file!");
            let file = File::open(tmpTarget).expect("Could not open tmp target!");
            let mut perms = file.metadata()?.permissions();
            // TODO: handle octal and string format modes?
            perms.set_mode($mod);
            // Should set uid/gid on symlink or symlink destination?
            fs::lchown($tmpTarget, Some($uid), Some($gid)).expect("Could set target.tmp uid/gid");
            match fs::rename(tmpTarget, target) {
                Ok(()) => {},
                Err(e) => {
                    eprintln!("Could not rename $target.tmp to $target!");
                    std::fs::remove_file(tmpTarget).expect("Could not unlink $target.tmp");
                }
            }
        }
        copied.insert($file_name);
        //TODO: append to CLEAN list.
    else if (-l $file_name) {
        atomic_symlink(fomatln!("/tmp/etc/static/{file_name}"), target).expect(format!("Could not create symlink $target"));
    }
}

fn main() {
    let args: Vec<String> = env::args().collect();
    //dbg!(args);
    assert_eq!(args.len(), 2);
    let etc = &args[1];
    let static_etc = "/tmp/etc/static";
    let _ = atomic_symlink(&etc, static_etc);

    println!("is literal? {}", is_static(Path::new("/tmp/etc/static")));
    let _ = find(&Path::new("/tmp/etc"),  cleanup);

    let old_copied = fs::read_to_string("/etc/.clean")
      .expect("/etc.clean did not exist!");
    let mut open_clean = File::create("/etc/.clean").unwrap();
    // write sorted $copied to .clean
    // Create /etc/NIXOS tag?
}
