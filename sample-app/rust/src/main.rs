use serde::Serialize;

#[derive(Serialize)]
struct Greeting { id: String, msg: &'static str }

fn main() {
    let g = Greeting { id: uuid::Uuid::new_v4().to_string(), msg: "hello sbom" };
    println!("{}", serde_json::to_string(&g).unwrap());
}
