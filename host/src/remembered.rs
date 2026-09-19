//! Browser grants are independent random secrets, never stored pairing passwords.
use rand::RngCore;
use serde::{Deserialize, Serialize};
use sha2::{Digest, Sha256};
use std::{fs, io, path::Path};

#[derive(Default, Serialize, Deserialize)]
struct Grants {
    version: u32,
    password_tag: String,
    hashes: Vec<String>,
}
fn digest(text: &str) -> String {
    format!("{:x}", Sha256::digest(text.as_bytes()))
}
fn read(path: &Path) -> io::Result<Grants> {
    if !path.exists() {
        return Ok(Grants::default());
    }
    if fs::metadata(path)?.len() > 16384 {
        return Err(io::Error::other("grant store too large"));
    }
    serde_json::from_slice(&fs::read(path)?).map_err(io::Error::other)
}
fn write(path: &Path, grants: &Grants) -> io::Result<()> {
    if let Some(parent) = path.parent() {
        fs::create_dir_all(parent)?;
    }
    let tmp = path.with_extension("tmp");
    fs::write(&tmp, serde_json::to_vec(grants)?)?;
    fs::rename(tmp, path)
}
fn valid_at(path: &Path, token: &str, password: &str) -> bool {
    if token.len() != 64 || !token.bytes().all(|c| c.is_ascii_hexdigit()) {
        return false;
    }
    let Ok(g) = read(path) else {
        return false;
    };
    g.version == 1 && g.password_tag == digest(password) && g.hashes.contains(&digest(token))
}
fn issue_at(path: &Path, password: &str) -> io::Result<String> {
    let mut g = read(path)?;
    let tag = digest(password);
    if g.password_tag != tag {
        g = Grants {
            version: 1,
            password_tag: tag,
            hashes: vec![],
        };
    }
    if g.hashes.len() >= 64 {
        return Err(io::Error::other(
            "64 remembered browsers; revoke unused access first",
        ));
    }
    let mut bytes = [0u8; 32];
    rand::rngs::OsRng.fill_bytes(&mut bytes);
    let token = bytes.iter().map(|b| format!("{b:02x}")).collect::<String>();
    g.hashes.push(digest(&token));
    write(path, &g)?;
    Ok(token)
}
fn path() -> std::path::PathBuf {
    crate::identity::config_dir().join("remembered-browsers.json")
}
pub fn current_password() -> io::Result<String> {
    fs::read_to_string(crate::identity::config_dir().join("password"))
}
pub fn valid(token: &str, password: &str) -> bool {
    valid_at(&path(), token, password)
}
pub fn issue(password: &str) -> io::Result<String> {
    issue_at(&path(), password)
}
pub fn revoke_all() -> io::Result<()> {
    write(&path(), &Grants::default())
}

#[cfg(test)]
mod tests {
    use super::*;
    fn temp() -> std::path::PathBuf {
        std::env::temp_dir()
            .join(format!("xydesk-grants-{}", rand::random::<u64>()))
            .join("grants.json")
    }
    #[test]
    fn token_not_password_is_persisted_and_survives_reload() {
        let p = temp();
        let t = issue_at(&p, "SecretA").unwrap();
        let raw = fs::read_to_string(&p).unwrap();
        assert!(!raw.contains(&t));
        assert!(!raw.contains("SecretA"));
        assert!(valid_at(&p, &t, "SecretA"));
        assert!(!valid_at(&p, &t, "SecretB"));
        assert!(!valid_at(&p, "bad", "SecretA"));
        write(&p, &Grants::default()).unwrap();
        assert!(!valid_at(&p, &t, "SecretA"));
        fs::remove_dir_all(p.parent().unwrap()).unwrap();
    }
    #[test]
    fn password_rotation_does_not_reactivate_old_grants() {
        let p = temp();
        let a = issue_at(&p, "PasswordA").unwrap();
        let b = issue_at(&p, "PasswordB").unwrap();
        assert!(!valid_at(&p, &a, "PasswordA"));
        assert!(!valid_at(&p, &a, "PasswordB"));
        assert!(valid_at(&p, &b, "PasswordB"));
        fs::remove_dir_all(p.parent().unwrap()).unwrap();
    }
    #[test]
    fn corrupt_missing_foreign_and_over_capacity_fail_closed() {
        let p = temp();
        assert!(!valid_at(&p, &"a".repeat(64), "PasswordA"));
        let t = issue_at(&p, "PasswordA").unwrap();
        let q = temp();
        assert!(!valid_at(&q, &t, "PasswordA"));
        for _ in 1..64 {
            issue_at(&p, "PasswordA").unwrap();
        }
        assert!(issue_at(&p, "PasswordA").is_err());
        assert!(valid_at(&p, &t, "PasswordA"));
        fs::write(&p, "broken").unwrap();
        assert!(!valid_at(&p, &t, "PasswordA"));
        assert!(issue_at(&p, "PasswordA").is_err());
        fs::remove_dir_all(p.parent().unwrap()).unwrap();
    }
}
