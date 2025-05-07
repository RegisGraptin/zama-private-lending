import Dashboard from "@/components/Dashboard";
import Header from "@/components/Header";

export default function Home() {
  return (
    <>
      <div className="min-h-screen bg-gray-900 text-white font-inter">
        <Header />
        <Dashboard />
      </div>
    </>
  );
}
