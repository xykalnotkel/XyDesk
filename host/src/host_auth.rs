//! Short signaling tickets are renewed inside the engine without changing its ID.
#[cfg(target_os = "windows")]
pub async fn token(id: &str) -> Result<String, String> {
    let id = id.to_owned();
    tokio::task::spawn_blocking(move || fetch(&id))
        .await
        .map_err(|_| "token worker stopped".to_string())?
}
#[cfg(not(target_os = "windows"))]
pub async fn token(_id: &str) -> Result<String, String> {
    Err("managed auth requires Windows".into())
}
#[cfg(target_os = "windows")]
fn fetch(id: &str) -> Result<String, String> {
    use std::{fs, time::Duration};
    let password = crate::remembered::current_password().map_err(|_| "identity unavailable")?;
    let path = crate::identity::config_dir().join("host-refresh.json");
    let stored = if path.exists() {
        let data = fs::read(&path).map_err(|_| "refresh unreadable")?;
        let value: serde_json::Value =
            serde_json::from_slice(&data).map_err(|_| "refresh corrupt")?;
        if value["id"].as_str() != Some(id) {
            return Err("refresh identity mismatch".into());
        }
        Some(
            value["refresh"]
                .as_str()
                .ok_or("refresh missing")?
                .to_owned(),
        )
    } else {
        None
    };
    let mut body = serde_json::json!({"id":id,"claim":password,"v":2});
    if let Some(refresh) = stored {
        body["refresh"] = serde_json::json!(refresh);
    }
    let response = ureq::post("https://signal.xydesk.my.id/host-token")
        .timeout(Duration::from_secs(15))
        .send_json(body)
        .map_err(|e| match e {
            ureq::Error::Status(code, _) => format!("token endpoint HTTP {code}"),
            _ => "token endpoint unreachable".into(),
        })?;
    let value: serde_json::Value = response.into_json().map_err(|_| "invalid token response")?;
    let token = value["token"].as_str().ok_or("missing token")?;
    if !valid_ticket(token, id) {
        return Err("invalid token shape".into());
    }
    let refresh = value["refresh"].as_str().ok_or("missing refresh")?;
    if !valid_ticket(refresh, id) {
        return Err("invalid refresh shape".into());
    }
    let tmp = path.with_extension("tmp");
    fs::write(
        &tmp,
        serde_json::to_vec(&serde_json::json!({"id":id,"refresh":refresh}))
            .map_err(|_| "refresh encoding")?,
    )
    .map_err(|_| "refresh save failed")?;
    fs::rename(tmp, path).map_err(|_| "refresh replace failed")?;
    Ok(token.to_owned())
}
fn valid_ticket(token: &str, id: &str) -> bool {
    let p: Vec<_> = token.split('.').collect();
    p.len() == 3
        && !p[0].is_empty()
        && p[0].bytes().all(|b| b.is_ascii_digit())
        && p[1] == id
        && p[2].len() == 64
        && p[2].bytes().all(|b| b.is_ascii_hexdigit())
}
#[cfg(test)]
mod tests {
    use super::*;
    #[test]
    fn tokens_are_bound_to_device_and_not_log_text() {
        let t = format!("123.123456789.{}", "a".repeat(64));
        assert!(valid_ticket(&t, "123456789"));
        assert!(!valid_ticket(&t, "987654321"));
        assert!(!valid_ticket("secret response", "123456789"));
        assert!(!valid_ticket(".123456789.x", "123456789"));
    }
}
