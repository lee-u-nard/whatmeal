import java.net.*;
import java.nio.channels.*;
public class LoopbackProbe {
  public static void main(String[] args) {
    System.out.println("java=" + System.getProperty("java.version"));
    try (var pipe = Pipe.open().source()) { System.out.println("nio-pipe=OK"); }
    catch (Exception e) { System.out.println("nio-pipe="+e); }
    try (var selector = Selector.open()) { System.out.println("nio-selector=OK"); }
    catch (Exception e) { System.out.println("nio-selector="+e); e.printStackTrace(); }
    for (String address : new String[]{"127.0.0.1", "::1"}) {
      try (var server = new ServerSocket()) {
        server.bind(new InetSocketAddress(InetAddress.getByName(address), 0));
        server.setSoTimeout(3000);
        try (var client = new Socket()) {
          client.connect(server.getLocalSocketAddress(), 3000);
          try (var accepted = server.accept()) { System.out.println(address+"=OK"); }
        }
      } catch(Exception e) { System.out.println(address+"="+e); }
    }
  }
}
